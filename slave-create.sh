#!/usr/bin/env sh

# The MIT License
#
#  Copyright (c) 2015, CloudBees, Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

# Usage jenkins-slave.sh [options] -url http://jenkins [JENKINS_API_TOKEN] [JENKINS_USER]
# Optional environment variables :
# * JENKINS_TUNNEL : HOST:PORT for a tunnel to route TCP traffic to jenkins host, when jenkins can't be directly accessed over network
# * JENKINS_URL : alternate jenkins URL
# * JENKINS_USER : jenkins user with access to rest api, has to be defined as otherwise the script will exit
# * JENKINS_API_TOKEN : api token of jenkins user which uses the rest api, has to be defined as otherwise the script will fail
# * JENKINS_AGENT_WORKDIR : agent work directory, if not set by optional parameter -workDir
# * JENKINS_AGENT_LABELS: labels for the jenkins node
# * ENVRIONMENT_VARS: Define node specific environment variables in the form 
#                {'key':+'JAVA_HOME',+'value':+'/docker-java-home'},+{'key':+'JENKINS_HOME',+'value':+'/home/jenkins'}"
# * LOCATIONS: Define node specific locations in the form 
#                {'key':+'hudson.plugins.git.GitTool\\$DescriptorImpl@Default',+'home':+'/usr/bin/git'},+{'key':+'hudson.model.JDK\\$DescriptorImpl@JAVA-8',+'home':+'/usr/bin/java'}

#Define cleanup procedure
cleanup() {
    echo "Container stopped, performing cleanup..."
	RESULT=$(curl -k -L -s -o /dev/null -v -k -w "%{http_code}" -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -X POST -d "" "${JENKINS_URL}/computer/${JENKINS_AGENT_NAME}/doDelete")
	exit 1
}

#Trap SIGTERM (use without prefix SIG for sh)
#TODO: Cleanup does not yet work, need to figure out why signal is not caught
trap 'cleanup' 1 2 9

if [ $# -eq 1 ]; then

	# if `docker run` only has one arguments, we assume user is running alternate command like `bash` to inspect the image
	exec "$@"

else

	# if -tunnel is not provided, try env vars
	case "$@" in
		*"-tunnel "*) ;;
		*)
		if [ ! -z "$JENKINS_TUNNEL" ]; then
			TUNNEL="-tunnel $JENKINS_TUNNEL"
		fi ;;
	esac

	# if -workDir is not provided, try env vars
	if [ ! -z "$JENKINS_AGENT_WORKDIR" ]; then
		case "$@" in
			*"-workDir"*) echo "Warning: Work directory is defined twice in command-line arguments and the environment variable" ;;
			*)
			WORKDIR="-workDir $JENKINS_AGENT_WORKDIR" ;;
		esac
	fi

	# get url of jenkins
	case "$@" in
		*"-url "*) 
			JENKINS_URL=$(echo "$@" | grep -oP "\-url\s+\Khttps?://[^ ]+")
		;;
		*)
		if [ ! -z "$JENKINS_URL" ]; then
			URL="-url $JENKINS_URL"
		fi
	esac

	echo JENKINS_URL is $JENKINS_URL

	JENKINS_AGENT_NAME=$(hostname)
	echo AGENT NAME is $JENKINS_AGENT_NAME
	# if [ -n "$JENKINS_NAME" ]; then
	# 	JENKINS_AGENT_NAME="$JENKINS_NAME"
	# fi  

	if [ -z "$JNLP_PROTOCOL_OPTS" ]; then
		echo "Warning: JnlpProtocol3 is disabled by default, use JNLP_PROTOCOL_OPTS to alter the behavior"
		JNLP_PROTOCOL_OPTS="-Dorg.jenkinsci.remoting.engine.JnlpProtocol3.disabled=true"
	fi
	
	# if java home is defined, use it
	JAVA_BIN="java"
	if [ "$JAVA_HOME" ]; then
		JAVA_BIN="$JAVA_HOME/bin/java"
	fi

	echo USER IS $JENKINS_USER
	if [ -z "$JENKINS_USER" ]; then
		echo "ERROR: JENKINS_USER is not defined defined"
		exit 1
	fi

	if [ -z "$JENKINS_API_TOKEN" ]; then
		echo "ERROR: JENKINS_API_TOKEN is not defined defined"
		exit 1
	fi
	
	#TODO: Handle the case when the command-line and Environment variable contain different values.
	#It is fine it blows up for now since it should lead to an error anyway.

    # create node
    export JSON_OBJECT="{ 'name':+'${JENKINS_AGENT_NAME}',+'nodeDescription':+'Linux+slave',+'numExecutors':+'5',+'remoteFS':+'/home/jenkins/agent',+'labelString':+'${JENKINS_AGENT_LABELS}',+'mode':+'EXCLUSIVE',+'':+['hudson.slaves.JNLPLauncher',+'hudson.slaves.RetentionStrategy\$Always'],+'launcher':+{'stapler-class':+'hudson.slaves.JNLPLauncher',+'\$class':+'hudson.slaves.JNLPLauncher',+'workDirSettings':+{'disabled':+true,+'workDirPath':+'',+'internalDir':+'remoting',+'failIfWorkDirIsMissing':+false},+'tunnel':+'',+'vmargs':+'-Xmx1024m'},+'retentionStrategy':+{'stapler-class':+'hudson.slaves.RetentionStrategy\$Always',+'\$class':+'hudson.slaves.RetentionStrategy\$Always'},+'nodeProperties':+{'stapler-class-bag':+'true',+'hudson-slaves-EnvironmentVariablesNodeProperty':+{'env':+[${ENVIRONMENT_VARS}]},+'hudson-tools-ToolLocationNodeProperty':+{'locations':+[${LOCATIONS}]}}}"
	echo Create Jenkins Slave ${JENKINS_AGENT_NAME}
    RESULT=$(curl -k -L -s -o /dev/null -w "%{http_code}" -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -H "Content-Type:application/x-www-form-urlencoded" -X POST -d "json=${JSON_OBJECT}" "${JENKINS_URL}/computer/doCreateItem?name=${JENKINS_AGENT_NAME}&type=hudson.slaves.DumbSlave")
	if [ $RESULT -eq "200"]; then
		echo Jenkins Slave ${JENKINS_AGENT_NAME} created: $RESULT
	elif [ $RESULT -eq "400"]; then
	 	echo Jenkins Slave ${JENKINS_AGENT_NAME} already exists: $RESULT
	else
	 	echo ERROR creating Jenkins Slave ${JENKINS_AGENT_NAME}: $RESULT
	fi

	# get node secret
	echo get secret from ${JENKINS_URL}/computer/${JENKINS_AGENT_NAME}/slave-agent.jnlp
	JENKINS_JNLP=$(curl -L -k -s -u ${JENKINS_USER}:${JENKINS_API_TOKEN} -X GET ${JENKINS_URL}/computer/${JENKINS_AGENT_NAME}/slave-agent.jnlp)
	printf "JENKINS_JNLP:\n$JENKINS_JNLP"
	JENKINS_SECRET_OPT=$(echo $JENKINS_JNLP | sed "s/.*<application-desc main-class=\"hudson.remoting.jnlp.Main\"><argument>\([a-z0-9]*\).*/\1/")
	
	if [ -z $JENKINS_SECRET_OPT ]; then
		echo JENKINS_SECRET_OPT is empty, give it another try
		JENKINS_SECRET_OPT=$(echo $JENKINS_JNLP | sed "s/.*<argument>\([a-z0-9]{64}\)<.*/\1/")
		if [ -z $JENKINS_SECRET_OPT ]; then
			# if all fails, you still can use the environment variable	
			echo JENKINS_SECRET_OPT is empty, use JENKINS_SECRET environment
			JENKINS_SECRET_OPT=$JENKINS_SECRET
		fi
	fi

	echo NODESECRET is $JENKINS_SECRET_OPT

	# start agent
	$JAVA_BIN $JAVA_OPTS $JNLP_PROTOCOL_OPTS -cp /usr/share/jenkins/slave.jar hudson.remoting.jnlp.Main -headless $TUNNEL $URL $WORKDIR $JENKINS_SECRET_OPT $JENKINS_AGENT_NAME "$@" &
	PID="$!"
	wait $PID
fi