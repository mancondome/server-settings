sudo apt-get install npm
sudo useradd -m -d /var/lib/node -s /bin/false node
sudo mkdir /var/log/nginx/node 2> /dev/null
cat <<EOF | sudo tee /etc/nginx/sites-available/node > /dev/null
upstream node {
  server 127.0.0.1:3000;
}

server {
  listen 80;
  server_name `hostname -f`;
  access_log /var/log/nginx/node/access.log;
  error_log /var/log/nginx/node/error.log;

  location / {
  	proxy_pass http://node;
  }
}
EOF
