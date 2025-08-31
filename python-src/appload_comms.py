import socket
import json
import struct
import threading
import time
import logging
import os

logger = logging.getLogger(__name__)

# System message types
MSG_SYSTEM_TERMINATE = 0xFFFFFFFF
MSG_SYSTEM_NEW_COORDINATOR = 0xFFFFFFFE  
MSG_SYSTEM_UNKNOWN = 0xFFFFFFFD

MAX_PACKAGE_SIZE = 10485760

class AppLoadComms:
    def __init__(self, socket_path, message_handler):
        self.socket_path = socket_path
        self.message_handler = message_handler
        self.sock = None
        self.running = False
        self.connected = False

        logger.info(f"AppLoadComms initialized with socket: {socket_path}")

    def connect_to_appload(self):
        """Connect to AppLoad's coordinator socket with continuous retry"""
        logger.info("Starting connection thread")

        attempt = 0
        while self.running and not self.connected:
            attempt += 1
            try:
                if attempt % 10 == 1:
                    logger.info(f"Connection attempt {attempt}")

                if not os.path.exists(self.socket_path):
                    time.sleep(0.1)
                    continue

                logger.info(f"Attempting SEQPACKET connection to {self.socket_path}")

                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
                self.sock.settimeout(5.0)
                self.sock.connect(self.socket_path)

                logger.info("Connected to AppLoad coordinator!")
                self.connected = True
                return True

            except Exception as e:
                logger.error(f"Connection failed: {e}")
                if self.sock:
                    self.sock.close()
                    self.sock = None
                time.sleep(0.2)

        return False

    def send_message(self, msg_type, contents):
        """Send a message to the frontend"""
        logger.info(f"Sending message type {msg_type}")

        if not self.sock or not self.connected:
            logger.error("No socket available for sending message")
            return

        try:
            contents_bytes = contents.encode('utf-8')
            header = struct.pack('<II', msg_type, len(contents_bytes))

            # Send header first
            header_sent = self.sock.send(header)
            logger.debug(f"Sent header: {header_sent} bytes")

            # Send content second
            if len(contents_bytes) > 0:
                content_sent = self.sock.send(contents_bytes)
                logger.debug(f"Sent content: {content_sent} bytes")

            logger.info(f"Successfully sent message type {msg_type}")

        except Exception as e:
            logger.error(f"Error sending message: {e}")
            self.connected = False

    def receive_message(self):
        """Receive a message from AppLoad"""
        if not self.sock or not self.connected:
            return None, None

        try:
            self.sock.settimeout(1.0)

            logger.debug("Waiting for message header...")

            header_data = self.sock.recv(8)
            logger.debug(f"Received header: {len(header_data)} bytes")

            if len(header_data) < 8:
                logger.warning(f"Received incomplete header: {len(header_data)} bytes")
                if len(header_data) == 0:
                    logger.info("Connection closed by peer")
                    self.connected = False
                return None, None

            msg_type, length = struct.unpack('<II', header_data)
            logger.debug(f"Header - type: {msg_type}, length: {length}")

            if length > MAX_PACKAGE_SIZE:
                logger.error(f"Message too large: {length} bytes")
                return None, None

            if length > 0:
                logger.debug(f"Waiting for content ({length} bytes)...")

                content_data = self.sock.recv(length)
                logger.debug(f"Received content: {len(content_data)} bytes")

                if len(content_data) < length:
                    logger.warning(f"Content shorter than expected: got {len(content_data)}, expected {length}")
                    return None, None

                decoded_contents = content_data.decode('utf-8')
                logger.info(f"Received message type {msg_type}: {decoded_contents}")
                return msg_type, decoded_contents
            else:
                logger.info(f"Received message type {msg_type}: (no content)")
                return msg_type, ""

        except socket.timeout:
            logger.debug("Socket timeout - no message received")
            return None, None
        except Exception as e:
            logger.error(f"Error receiving message: {e}")
            self.connected = False
            return None, None

    def handle_system_message(self, msg_type, contents):
        """Handle system messages from AppLoad"""
        if msg_type == MSG_SYSTEM_NEW_COORDINATOR:
            logger.info("Frontend coordinator message received")

        elif msg_type == MSG_SYSTEM_TERMINATE:
            logger.info("Frontend terminating")
            self.running = False

        elif msg_type == MSG_SYSTEM_UNKNOWN:
            logger.info("System message (unknown type)")

    def run(self):
        """Main message loop"""
        self.running = True
        logger.info("AppLoad communications started")

        # Start connection thread
        connection_thread = threading.Thread(target=self.connect_to_appload)
        connection_thread.daemon = True
        connection_thread.start()

        logger.info("Waiting for messages...")

        message_count = 0
        while self.running:
            if self.connected:
                msg_type, contents = self.receive_message()
                if msg_type is not None:
                    message_count += 1
                    logger.info(f"Processing message #{message_count}")

                    # Handle system messages internally
                    if msg_type in [MSG_SYSTEM_TERMINATE, MSG_SYSTEM_NEW_COORDINATOR, MSG_SYSTEM_UNKNOWN]:
                        self.handle_system_message(msg_type, contents)
                    else:
                        # Pass application messages to handler
                        self.message_handler(msg_type, contents)
            else:
                time.sleep(0.1)

        logger.info("AppLoad communications shutting down")
        if self.sock:
            self.sock.close()
