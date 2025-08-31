import requests
import logging
import os

try:
    from bs4 import BeautifulSoup
    HAS_BS4 = True
except ImportError:
    HAS_BS4 = False
    print("Warning: BeautifulSoup not available. Install with: pip install beautifulsoup4")

logger = logging.getLogger(__name__)

class ReadeckClient:
    def __init__(self):
        self.config = self._load_config()
        self.base_url = self.config["base_url"].rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {self.config['api_key']}",
            "Content-Type": "application/json",
        }

    def _load_config(self):
        """Load configuration from ~/.rm-readeck file"""
        config_file = os.path.expanduser("~/.rm-readeck")
        config = {}

        try:
            with open(config_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()

            # Map to expected keys
            return {
                "base_url": config.get("READECK_URL"),
                "api_key": config.get("READECK_API_KEY")
            }
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            raise

    def _clean_html_content(self, html_content):
        """Clean HTML content for better reading on e-ink display"""
        if not html_content or not HAS_BS4:
            return html_content, []

        soup = BeautifulSoup(html_content, 'html.parser')

        # Remove unwanted elements completely
        for element in soup(['script', 'style', 'nav', 'header', 'footer', 
                        'aside', 'iframe', 'form', 'button', 'input']):
            element.decompose()

        # Extract images before removing them
        images = []
        for img in soup.find_all('img'):
            src = img.get('src')
            alt = img.get('alt', '')
            if src:
                images.append({
                    'src': src,
                    'alt': alt,
                    'caption': alt or 'Image'
                })
            img.decompose()  # Remove from content

        # Convert common elements to readable text
        # Headers
        for i in range(1, 7):
            for header in soup.find_all(f'h{i}'):
                text = header.get_text().strip()
                if i <= 2:  # Main headers get more spacing
                    header.string = f"\n\n{text.upper()}\n\n"
                else:  # Smaller headers
                    header.string = f"\n\n{text}\n\n"

        # Lists
        for ul in soup.find_all('ul'):
            for li in ul.find_all('li'):
                li.string = f"• {li.get_text().strip()}\n"

        for ol in soup.find_all('ol'):
            for i, li in enumerate(ol.find_all('li'), 1):
                li.string = f"{i}. {li.get_text().strip()}\n"

        # Paragraphs - add proper spacing
        for p in soup.find_all('p'):
            if p.get_text().strip():
                p.string = f"{p.get_text().strip()}\n\n"

        # Block quotes
        for blockquote in soup.find_all('blockquote'):
            text = blockquote.get_text().strip()
            blockquote.string = f"\n> {text}\n\n"

        # Links - keep the text but note the URL
        for a in soup.find_all('a'):
            href = a.get('href')
            text = a.get_text().strip()
            if href and text:
                a.string = f"{text} [{href}]"
            elif text:
                a.string = text

        # Get clean text
        clean_text = soup.get_text()

        # Clean up whitespace
        import re
        clean_text = re.sub(r'\n\s*\n\s*\n+', '\n\n', clean_text)
        clean_text = re.sub(r'[ \t]+', ' ', clean_text)
        clean_text = clean_text.strip()

        return clean_text, images

    def fetch_articles(self, limit=20, offset=0):
        """Fetch articles from Readeck API"""
        logger.info(f"Fetching articles with limit={limit}, offset={offset}")
        print(f"Fetching articles with limit={limit}, offset={offset}")

        try:
            params = {
                "limit": limit,
                "offset": offset,
                "is_archived": "false",
                "sort": "asc"
            }

            print(f"DEBUG: Making request to: {self.base_url}/api/bookmarks")
            print(f"DEBUG: With params: {params}")

            response = requests.get(f"{self.base_url}/api/bookmarks", headers=self.headers, params=params)
            print(f"DEBUG: Response status: {response.status_code}")

            response.raise_for_status()

            data = response.json()
            print(f"DEBUG: Response type: {type(data)}")
            print(f"DEBUG: Raw response: {data}")

            # Handle different response formats
            if isinstance(data, list):
                # API returns list directly
                bookmarks = data
                total = len(data)
                print(f"DEBUG: API returned list with {len(bookmarks)} items")
            elif isinstance(data, dict):
                # API returns dict with bookmarks key
                bookmarks = data.get("bookmarks", [])
                total = data.get("total", len(bookmarks))
                print(f"DEBUG: API returned dict with {len(bookmarks)} bookmarks")
            else:
                print(f"DEBUG: Unexpected response type: {type(data)}")
                bookmarks = []
                total = 0

            articles = []

            for item in bookmarks:
                article = {
                    "id": item.get("id"),
                    "title": item.get("title", "Untitled"),
                    "url": item.get("url"),
                    "author": ", ".join(item.get("authors", [])) or "Unknown",
                    "createdAt": item.get("created_at"),
                    "tags": item.get("labels", []),
                    "readingTime": item.get("reading_time"),
                    "summary": item.get("description"),
                    "thumbnail": {
                        "src": item.get("resources", {}).get("thumbnail", {}).get("src"),
                        "height": item.get("resources", {}).get("thumbnail", {}).get("height"),
                        "width": item.get("resources", {}).get("thumbnail", {}).get("width"),
                    },
                }
                articles.append(article)

            logger.info(f"Successfully fetched {len(articles)} articles")
            print(f"DEBUG: Processed {len(articles)} articles")

            return {
                "articles": articles,
                "total": total,
                "limit": limit,
                "offset": offset
            }

        except Exception as e:
            logger.error(f"Error fetching articles: {str(e)}")
            print(f"Error fetching articles: {str(e)}")
            import traceback
            traceback.print_exc()
            return {"articles": [], "total": 0, "limit": limit, "offset": offset}


    def fetch_article_content(self, article_id):
        """Fetch full article content"""
        logger.info(f"Fetching full content for article {article_id}")
        print(f"Fetching full content for article {article_id}")

        try:
            # First fetch metadata
            meta_resp = requests.get(f"{self.base_url}/api/bookmarks/{article_id}", headers=self.headers)
            meta_resp.raise_for_status()
            meta = meta_resp.json()

            # Then fetch full article HTML
            article_url = meta.get("resources", {}).get("article", {}).get("src")
            if not article_url:
                logger.warning(f"No article content URL found for {article_id}")
                return None

            content_resp = requests.get(article_url, headers=self.headers)
            content_resp.raise_for_status()
            html_content = content_resp.text

            clean_content, images = self._clean_html_content(html_content)

            article = {
                "id": meta.get("id"),
                "title": meta.get("title", "Untitled"),
                "url": meta.get("url"),
                "author": ", ".join(meta.get("authors", [])) or "Unknown",
                "createdAt": meta.get("created_at"),
                "content": clean_content, 
                "images": images,  
                "tags": meta.get("labels", []),
                "readingTime": meta.get("reading_time"),
                "summary": meta.get("description"),
                "thumbnail": {
                    "src": meta.get("resources", {}).get("thumbnail", {}).get("src"),
                    "height": meta.get("resources", {}).get("thumbnail", {}).get("height"),
                    "width": meta.get("resources", {}).get("thumbnail", {}).get("width"),
                },
            }

            logger.info(f"Successfully fetched content for article: {article['title']}")
            logger.info(f"Found {len(images)} images in article")
            return article

        except Exception as e:
            logger.error(f"Error fetching article content {article_id}: {str(e)}")
            print(f"Error fetching article content {article_id}: {str(e)}")
            return None


    def mark_as_read(self, article_id):
        """Mark an article as read"""
        logger.info(f"Marking article {article_id} as read")
        print(f"Marking article {article_id} as read")

        try:
            # Add 'read' label to mark as read
            response = requests.post(
                f"{self.base_url}/bookmarks/{article_id}/labels",
                headers=self.headers,
                json={"name": "read"}
            )
            response.raise_for_status()

            logger.info(f"Successfully marked article {article_id} as read")
            return True

        except Exception as e:
            logger.error(f"Error marking article {article_id} as read: {str(e)}")
            return False

    def test_connection(self):
        """Test connection to Readeck API"""
        logger.info("Testing connection to Readeck API")

        try:
            response = requests.get(f"{self.base_url}/bookmarks", headers=self.headers, params={"limit": 1})
            response.raise_for_status()

            logger.info("Successfully connected to Readeck API")
            return True

        except Exception as e:
            logger.error(f"Failed to connect to Readeck API: {str(e)}")
            return False
