FROM mysql/mysql-server:5.6

# Define environment variable
EXPOSE 3306

VOLUME /vagrant/common/mysql/data:/var/lib/mysql

ENV MYSQL_ROOT_PASSWORD root

ENV MYSQL_USER user
ENV MYSQL_DATABASE testdatabase
ENV MYSQL_CONTAINER_NAME mysql

ENV MYSQL_PASSWORD user