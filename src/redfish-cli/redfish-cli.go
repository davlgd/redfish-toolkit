package main

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
)

const (
	exitCodeOk        = 0
	exitCodeGeneral   = 1
	exitCodeUsage     = 2
	exitCodeDataFetch = 3
	exitCodeJsonParse = 4
)

// generateAuthHeader creates the Basic Authorization header from user credentials.
func generateAuthHeader(u string) string {
	auth := base64.StdEncoding.EncodeToString([]byte(u))
	return "Basic " + auth
}

// createURL constructs the URL for the RedFish API call.
func createURL(ip, endpoint string) string {
	return fmt.Sprintf("https://%s/redfish/v1/%s", ip, endpoint)
}

// handleError prints the error message and exits the program with the given exit code.
func handleError(message string, code int) {
	fmt.Println(message)
	os.Exit(code)
}

func fetchData(ip, u, endpoint string, noTLSCheck bool) ([]byte, error) {
	url := createURL(ip, endpoint)
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: noTLSCheck},
	}
	client := &http.Client{Transport: tr}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Authorization", generateAuthHeader(u))
	req.Header.Add("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP error %d: %s", resp.StatusCode, resp.Status)
	}
	return io.ReadAll(resp.Body)
}

func processMembers(ip, u string, noTLSCheck bool, members []interface{}) ([]interface{}, error) {
	var wg sync.WaitGroup
	resultsChan := make(chan interface{}, len(members))
	errChan := make(chan error, len(members))
	var resultsErr []error

	for _, member := range members {
		wg.Add(1)
		go func(member interface{}) {
			defer wg.Done()
			memberMap, ok := member.(map[string]interface{})
			if !ok {
				errChan <- errors.New("error processing JSON member")
				return
			}
			if id, ok := memberMap["@odata.id"].(string); ok {
				id = strings.TrimPrefix(id, "/redfish/v1/")
				data, err := fetchData(ip, u, id, noTLSCheck)
				if err != nil {
					errChan <- fmt.Errorf("error fetching data for %s: %v", id, err)
					return
				}
				var resultData interface{}
				if err := json.Unmarshal(data, &resultData); err != nil {
					errChan <- fmt.Errorf("error decoding JSON for %s: %v", id, err)
					return
				}
				resultsChan <- resultData
			}
		}(member)
	}

	go func() {
		wg.Wait()
		close(resultsChan)
		close(errChan)
	}()

	results := make([]interface{}, 0)
	for result := range resultsChan {
		results = append(results, result)
	}
	for err := range errChan {
		resultsErr = append(resultsErr, err)
	}
	if len(resultsErr) > 0 {
		return results, fmt.Errorf("errors occurred during processing: %v", resultsErr)
	}
	return results, nil
}

func main() {
	ip := flag.String("ip", "", "Server IP address")
	u := flag.String("u", "", "Authentication user:pass")
	e := flag.String("e", "", "RedFish endpoint")
	help := flag.Bool("help", false, "Display help")
	noTLSCheck := flag.Bool("no-tls-check", false, "Disable TLS verification")
	members := flag.Bool("members", false, "Explore and fetch each member of the 'Members' JSON key")

	flag.Usage = func() {
		fmt.Fprintf(flag.CommandLine.Output(), "Usage of %s:\n", flag.CommandLine.Name())
		flag.PrintDefaults()
		os.Exit(exitCodeUsage)
	}
	flag.Parse()

	if *help {
		flag.Usage()
	}
	if *ip == "" || *u == "" || *e == "" {
		handleError("Error: Flags -ip, -u, and -e are mandatory.", exitCodeUsage)
	}

	body, err := fetchData(*ip, *u, *e, *noTLSCheck)
	if err != nil {
		handleError("Error fetching data: "+err.Error(), exitCodeDataFetch)
	}

	if *members {
		var jsonData map[string]interface{}
		if err := json.Unmarshal(body, &jsonData); err != nil {
			handleError("Error decoding JSON: "+err.Error(), exitCodeJsonParse)
		}
		if membersList, ok := jsonData["Members"].([]interface{}); ok {
			results, err := processMembers(*ip, *u, *noTLSCheck, membersList)
			if err != nil {
				handleError(err.Error(), exitCodeGeneral)
			}
			resultJSON, err := json.MarshalIndent(results, "", "  ")
			if err != nil {
				handleError("Error formatting JSON: "+err.Error(), exitCodeJsonParse)
			}
			fmt.Println(string(resultJSON))
		} else {
			handleError("Error: 'Members' key does not correspond to a list in the JSON.", exitCodeGeneral)
		}
		return
	}

	var formattedJSON bytes.Buffer
	if err := json.Indent(&formattedJSON, body, "", "  "); err != nil {
		handleError("Error formatting JSON: "+err.Error(), exitCodeJsonParse)
	}
	fmt.Println(formattedJSON.String())
}
