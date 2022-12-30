#!/bin/bash
echo "Hello, World" > index.html
nohup basybox httpd -f -p 8080 &