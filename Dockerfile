ARG APP_IMAGE=jenkins/jnlp-slave:latest
FROM $APP_IMAGE
USER root

# install git and docker
RUN apt-get update
RUN apt-get upgrade --assume-yes
RUN apt-get install --assume-yes git
RUN apt-get install --assume-yes maven
RUN apt-get install --assume-yes nano

# Un-comment below in case you need special certificates
# Use custom truststore for java
# COPY cacerts $JAVA_HOME/jre/lib/security/cacerts
## cacerts for JDK11
# COPY cacerts $JAVA_HOME/lib/security/cacerts
# Configure git to use custom certificates
# COPY ca-chain.pem  /etc/ssl/certs/ca-certificates.crt 
# Configure maven
# COPY settings.xml /etc/maven/settings.xml
# COPY security-settings.xml /etc/maven/security-settings.xml
# ENV MAVEN_OPTS -"Xmx512m -Duser.language=en -Duser.country=US -Duser.variant=US -Dsettings.security=/etc/maven/security-settings.xml"
# Copy custom jenkins start script
COPY slave-create.sh /usr/local/bin/jenkins-slave
RUN chmod +x /usr/local/bin/jenkins-slave
ENTRYPOINT [ "jenkins-slave" ]
