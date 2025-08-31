#!/usr/bin/env python3
import sys
import json
import logging
import argparse
import requests
import os
from appload_comms import AppLoadComms
from readeck_client import ReadeckClient

# Set up logging
logging.basicConfig(
    filename='/tmp/readeck-backend.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

# Message types
ARTICLES_REQUEST = 1
ARTICLES_RESPONSE = 101
MARK_READ_REQUEST = 2
MARK_READ_RESPONSE = 102
GET_ARTICLE_CONTENT = 3
ARTICLE_CONTENT_RESPONSE = 103


class ReadeckApp:
    def __init__(self, socket_path):  
        self.readeck_client = ReadeckClient()  
        self.appload = AppLoadComms(socket_path, self.handle_message)

        logger.info(f"ReadeckApp initialized")
        print(f"ReadeckApp initialized")

    def handle_message(self, msg_type, contents):
        """Handle messages from the QML frontend"""
        logger.info(f"Handling message type {msg_type}: {contents}")

        if msg_type == ARTICLES_REQUEST:
            logger.info("Frontend requested articles - fetching from Readeck")
            self.send_unread_articles()

        elif msg_type == MARK_READ_REQUEST:
            logger.info(f"Frontend wants to mark article as read: {contents}")
            self.mark_article_read(contents)
        
        elif msg_type == GET_ARTICLE_CONTENT:
            article_id = contents.strip()
            logger.info(f"Fetching content for article: {article_id}")

            article = self.readeck_client.fetch_article_content(article_id)
            if article:
                response = json.dumps({"success": True, "article": article})
                logger.info(f"Sending article content response")
            else:
                response = json.dumps({"success": False, "error": "Failed to fetch article content"})
                logger.error(f"Failed to fetch article content for {article_id}")

            self.appload.send_message(ARTICLE_CONTENT_RESPONSE, response)  # This was correct


        else:
            logger.warning(f"Unknown message type: {msg_type}")

    def send_unread_articles(self):
        """Fetch unread articles from Readeck and send to frontend"""
        logger.info("Fetching unread articles from Readeck API")

        try:
            # Debug the API call
            result = self.readeck_client.fetch_articles()

            if isinstance(result, dict):
                print(f"DEBUG: Response keys: {result.keys()}")
                articles = result.get('articles', [])
                print(f"DEBUG: Articles count: {len(articles)}")
                if articles:
                    print(f"DEBUG: First article: {articles[0]}")
            else:
                print(f"DEBUG: Unexpected response type: {type(result)}")
                articles = []

            logger.info(f"Fetched {len(articles)} articles from Readeck")

            # Rest of your existing code...
            response_data = {
                "articles": [
                    {
                        "id": article.get("id"),
                        "title": article.get("title", "Untitled"),
                        "url": article.get("url", ""),
                        "summary": article.get("summary"),
                        "author": article.get("author", "Unknown"),
                        "created_at": article.get("createdAt", ""),
                        "tags": article.get("tags", []),
                        "reading_time": article.get("readingTime", 0),
                        "thumbnail": article.get("thumbnail"),
                    }
                    for article in articles
                ]
            }

            json_response = json.dumps(response_data)
            logger.info(f"Sending {len(articles)} articles to frontend")
            self.appload.send_message(ARTICLES_RESPONSE, json_response)

        except Exception as e:
            logger.error(f"Error fetching articles: {e}")
            import traceback
            traceback.print_exc()

            error_response = {
                "articles": [],
                "error": str(e)
            }
            self.appload.send_message(ARTICLES_RESPONSE, json.dumps(error_response))


    def mark_article_read(self, article_id):
        """Mark an article as read in Readeck"""
        logger.info(f"Marking article {article_id} as read")
        print(f"Marking article {article_id} as read")

        try:
            success = self.readeck_client.mark_as_read(article_id)
            logger.info(f"Mark as read result: {success}")

            response_data = {
                "success": success,
                "article_id": article_id
            }

            self.appload.send_message(MARK_READ_RESPONSE, json.dumps(response_data))

        except Exception as e:
            logger.error(f"Error marking article as read: {e}")
            print(f"Error marking article as read: {e}")

            response_data = {
                "success": False,
                "article_id": article_id,
                "error": str(e)
            }
            self.appload.send_message(MARK_READ_RESPONSE, json.dumps(response_data))

    def truncate_content(self, content, max_length=200):
        """Create a summary from article content"""
        if not content:
            return "No summary available"

        # Strip HTML tags roughly
        import re
        clean_content = re.sub(r'<[^>]+>', '', content)

        if len(clean_content) <= max_length:
            return clean_content

        return clean_content[:max_length].rsplit(' ', 1)[0] + "..."

    def run(self):
        """Start the application"""
        logger.info("Starting Readeck app")
        self.appload.run()

def main():
    if len(sys.argv) < 2:
        logger.error("Socket path not provided by AppLoad")
        sys.exit(1)

    socket_path = sys.argv[1]

    logger.info(f"Starting with socket: {socket_path}")

    app = ReadeckApp(socket_path)  # Remove the URL and API key parameters

    try:
        app.run()
    except KeyboardInterrupt:
        logger.info("Shutting down due to KeyboardInterrupt")
    except Exception as e:
        logger.error(f"Application error: {e}")

if __name__ == "__main__":
    main()
