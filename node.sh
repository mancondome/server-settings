# install
sudo apt-get install npm
sudo useradd -m -d /var/lib/node -s /bin/false node

# Nginx setting
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

  proxy_redirect                          off;
  proxy_set_header Host                   $host;
  proxy_set_header X-Real-IP              $remote_addr;
  proxy_set_header X-Forwarded-Host       $host;
  proxy_set_header X-Forwarded-Server     $host;
  proxy_set_header X-Forwarded-For        $proxy_add_x_forwarded_for;

  location / {
  	proxy_pass http://node;
  }
}
EOF
sudo ln -s /etc/nginx/sites-available/node /etc/nginx/sites-enabled/node

# log directory
sudo mkdir /var/log/node
sudo chown node:node /var/log/node/

# install ipcheck application
cat <<EOF | sudo -u node tee /var/lib/node/ipcheck.js
var httpd = require('http').createServer(function(request, response) {
    response.setHeader('Content-Type', 'text/plain');
    response.write(request.headers['x-real-ip']);
    response.end();
});
httpd.listen(3000);
EOF

cat <<EOF | sudo tee /etc/rc.local > /dev/null
#!/bin/sh -e
#
# rc.local
#

(sudo -u node node /var/lib/node/ipcheck.js >> /var/log/node/ipcheck.log) 2>> /var/log/node/ipcheck_error.log &
chown node:node /var/log/node/*.log
EOF
