#!/usr/bin/env python3

import os
import sys
import urllib3
import json

# Test configuration
HOST = "http://localhost"
PORT = 9200

# Create HTTP pool manager
http = urllib3.PoolManager()

def test_sudachi_analyzer():
    """Test basic Sudachi analyzer functionality"""
    print("Testing Sudachi analyzer...")
    
    body = {"analyzer": "sudachi", "text": ""}
    response = http.request(
        'POST',
        f"{HOST}:{PORT}/_analyze",
        headers={"Content-Type": "application/json"},
        body=json.dumps(body)
    )
    
    if response.status == 200:
        print("✅ Sudachi analyzer is available")
    else:
        print(f"❌ Sudachi analyzer test failed: {response.status}")
        sys.exit(1)

def test_sudachi_tokenizer():
    """Test Sudachi tokenizer with Japanese text"""
    print("\nTesting Sudachi tokenizer...")
    
    body = {"tokenizer": "sudachi_tokenizer", "text": "京都に行った"}
    response = http.request(
        'POST',
        f"{HOST}:{PORT}/_analyze",
        headers={"Content-Type": "application/json"},
        body=json.dumps(body)
    )
    
    if response.status == 200:
        data = json.loads(response.data)
        tokens = data.get("tokens", [])
        
        if len(tokens) == 4:
            print("✅ Tokenizer produced 4 tokens as expected")
            
            # Check specific tokens
            if tokens[0]["token"] == "京都" and tokens[1]["token"] == "に":
                print("✅ Token values are correct")
                
                # Check offsets
                if (tokens[0]["start_offset"] == 0 and 
                    tokens[0]["end_offset"] == 2 and
                    tokens[1]["start_offset"] == 2 and
                    tokens[1]["end_offset"] == 3):
                    print("✅ Token offsets are correct")
                else:
                    print("❌ Token offsets are incorrect")
            else:
                print(f"❌ Unexpected token values: {[t['token'] for t in tokens]}")
        else:
            print(f"❌ Expected 4 tokens, got {len(tokens)}")
    else:
        print(f"❌ Tokenizer test failed: {response.status}")
        sys.exit(1)

def test_explain_tokenizer():
    """Test tokenizer with explain flag"""
    print("\nTesting tokenizer with explain...")
    
    body = {
        "tokenizer": "sudachi_tokenizer",
        "text": "すだち",
        "explain": True
    }
    response = http.request(
        'POST',
        f"{HOST}:{PORT}/_analyze",
        headers={"Content-Type": "application/json"},
        body=json.dumps(body)
    )
    
    if response.status == 200:
        data = json.loads(response.data)
        
        # Check for morpheme data in detail
        if "detail" in data and "tokenizer" in data["detail"]:
            tokens = data["detail"]["tokenizer"].get("tokens", [])
            if tokens and "morpheme" in tokens[0]:
                morpheme = tokens[0]["morpheme"]
                
                # Check morpheme fields
                expected_fields = ["surface", "dictionaryForm", "normalizedForm", "readingForm", "partOfSpeech"]
                missing_fields = [f for f in expected_fields if f not in morpheme]
                
                if not missing_fields:
                    print("✅ All morpheme fields are present")
                    
                    # Check specific values
                    if (morpheme["surface"] == "すだち" and
                        morpheme["dictionaryForm"] == "すだち" and
                        morpheme["normalizedForm"] == "酢橘" and
                        morpheme["readingForm"] == "スダチ"):
                        print("✅ Morpheme values are correct")
                    else:
                        print("⚠️  Some morpheme values differ from expected")
                else:
                    print(f"❌ Missing morpheme fields: {missing_fields}")
            else:
                print("❌ No morpheme data in tokenizer output")
        else:
            print("❌ No detail information in response")
    else:
        print(f"❌ Explain test failed: {response.status}")

def test_sudachi_split_filter():
    """Test Sudachi split filter"""
    print("\nTesting Sudachi split filter...")
    
    # Create index with custom analyzer
    index_name = "test_sudachi_split"
    
    # Delete index if exists
    http.request('DELETE', f"{HOST}:{PORT}/{index_name}")
    
    # Create index with analyzer
    settings = {
        "settings": {
            "index": {
                "analysis": {
                    "tokenizer": {
                        "sudachi_tokenizer": {
                            "type": "sudachi_tokenizer"
                        }
                    },
                    "filter": {
                        "my_searchfilter": {
                            "type": "sudachi_split",
                            "mode": "search"
                        }
                    },
                    "analyzer": {
                        "sudachi_analyzer": {
                            "filter": ["my_searchfilter"],
                            "tokenizer": "sudachi_tokenizer",
                            "type": "custom"
                        }
                    }
                }
            }
        }
    }
    
    response = http.request(
        'PUT',
        f"{HOST}:{PORT}/{index_name}",
        headers={"Content-Type": "application/json"},
        body=json.dumps(settings)
    )
    
    if response.status in [200, 201]:
        print("✅ Created test index with split filter")
        
        # Test the analyzer
        body = {"analyzer": "sudachi_analyzer", "text": "関西国際空港"}
        response = http.request(
            'POST',
            f"{HOST}:{PORT}/{index_name}/_analyze",
            headers={"Content-Type": "application/json"},
            body=json.dumps(body)
        )
        
        if response.status == 200:
            data = json.loads(response.data)
            tokens = data.get("tokens", [])
            
            # Should have 4 tokens in search mode
            if len(tokens) >= 4:
                token_values = [t["token"] for t in tokens]
                if "関西国際空港" in token_values and "関西" in token_values:
                    print("✅ Split filter working correctly")
                else:
                    print(f"⚠️  Unexpected tokens: {token_values}")
            else:
                print(f"❌ Expected at least 4 tokens, got {len(tokens)}")
        
        # Cleanup
        http.request('DELETE', f"{HOST}:{PORT}/{index_name}")
    else:
        print(f"❌ Failed to create test index: {response.status}")

def main():
    print("=== Sudachi Plugin Integration Tests ===")
    print(f"Testing against {HOST}:{PORT}")
    print()
    
    # Check if OpenSearch is accessible
    try:
        response = http.request('GET', f"{HOST}:{PORT}/_cluster/health")
        if response.status == 200:
            print("✅ OpenSearch is accessible")
        else:
            print(f"❌ OpenSearch returned status {response.status}")
            sys.exit(1)
    except Exception as e:
        print(f"❌ Cannot connect to OpenSearch: {e}")
        sys.exit(1)
    
    # Run tests
    test_sudachi_analyzer()
    test_sudachi_tokenizer()
    test_explain_tokenizer()
    test_sudachi_split_filter()
    
    print("\n✅ All tests completed!")

if __name__ == "__main__":
    main()