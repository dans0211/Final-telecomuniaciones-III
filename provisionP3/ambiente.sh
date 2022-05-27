#Configuración ambiente de trabajo

echo "Instalar vim"
	yum install vim -y
	
echo "Instalar net-tools"
	yum install net-tools -y
	
echo "Deshabilitar Selinux"
	sed  's/#SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config