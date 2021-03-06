#Configuración de Firewall

echo "Instalar wget y java"
	yum install wget -y
	wget --no-cookies --no-check-certificate --header "Cookie:oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.rpm"
	yum -y localinstall jdk-8u131-linux-x64.rpm
	
echo "Instalar streama"
	wget https://github.com/streamaserver/streama/releases/download/v1.10.4/streama-1.10.4.jar
	
echo "Configurar streama"
	mkdir /opt/streama
	mv streama-1.10.4.jar /opt/streama/streama.jar

echo "Crear y configurar los directorios de contenido"
	mkdir /opt/streama/media
	chmod 664 /opt/streama/media
	
echo "Crear un systemd service para streama"
	touch /etc/systemd/system/streama.service
	
		cat <<TEST> /etc/systemd/system/streama.service
[Unit]
Description=Streama Server
After=syslog.target
After=network.target

[Service]
User=root
Type=simple
ExecStart=/bin/java -jar /opt/streama/streama.jar
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=Streama

[Install]
WantedBy=multi-user.target
TEST

systemctl start streama
systemctl enable streama

echo "Instalar Bind"
	yum install bind-utils bind-libs bind-* -y

echo "Modificando /etc/named.conf"	
	cat <<TEST> /etc/named.conf
options {
        listen-on port 53 { 127.0.0.1; 192.168.50.3; };
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { localhost; 192.168.50.0/24; };

        recursion yes;

        dnssec-enable yes;
        dnssec-validation yes;

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
		};	
};

zone "." IN {
        type hint;
        file "named.ca";
};

zone "streama.com" IN{
        type master;
        file "streama.com.fwd";
        allow-update { none; };
};

zone "50.168.192.in-addr.arpa" IN{
        type master;
        file "streama.com.rev";
        allow-update { none; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
TEST
	
echo "Creando los archivos de zona"
	cp /var/named/named.empty /var/named/streama.com.fwd
	cp /var/named/named.empty /var/named/streama.com.rev
	chmod 755 /var/named/streama.com.fwd
	chmod 755 /var/named/streama.com.rev
	
	cat <<TEST> /var/named/streama.com.fwd
$ORIGIN streama.com.
$TTL 3H"

@       IN SOA  servidor3.streama.com. root@streama.com. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       IN      NS      servidor.streama.com.

;host en la zona
servidor        IN      A       192.168.50.3
firewall        IN      A       192.168.1.20
TEST
	
	cat <<TEST> /var/named/streama.com.rev
$ORIGIN 50.168.192.in-addr.arpa.
TTL 3H
@       IN SOA  servidor.streama.com. root@streama.com. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       IN      NS      servidor.streama.com.

;host en la zona
3        IN      PTR     servidor.streama.com.
20       IN      PTR     firewall.streama.com.
TEST

echo "Levantando el servicio de DNS"
	service named start
	systemctl enable named
	
echo "Reconfigurando el /etc/resolv.conf"
	cat <<TEST> /etc/resolv.conf
nameserver 192.168.1.20
TEST

echo "Instalar httpd"
yum -y install httpd
systemctl start httpd
systemctl enable httpd

echo "Crear un VirtualHost para el servidor"
touch /etc/httpd/conf.d/servidor.streama.com.conf

	cat <<TEST> /etc/httpd/conf.d/servidor.streama.com.conf
<VirtualHost *:80>
    ServerName servidor.streama..com
    ServerAdmin root@streama.com
    ProxyPreserveHost On
    ProxyPass / http://192.168.50.3:8080/
    ProxyPassReverse / http://192.168.50.3:8080/
    TransferLog /var/log/httpd/streama.yourdomain.com_access.log
    ErrorLog /var/log/httpd/streama.yourdomain.com_error.log
</VirtualHost>
TEST

service httpd restart