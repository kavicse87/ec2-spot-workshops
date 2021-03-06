#!/bin/bash
yum update -y

sudo yum -y install python3 python3-wheel python-pi

cat <<EOF > requirements.txt
Flask==0.10.1
Flask-Cors==1.10.2
requests
boto3
EOF

sudo pip3 install -r requirements.txt


cat <<EOF > app.py
from flask import Flask, render_template
from flask.ext.cors import CORS, cross_origin
import os
import requests
import json
import time
import sys
import boto3
import datetime

app = Flask(__name__)
cors = CORS(app)
app.config['CORS_HEADERS'] = 'Content-Type'

URL = "http://169.254.169.254/latest/dynamic/instance-identity/document"
InstanceData = requests.get(URL).json()

@app.route('/')
@cross_origin()
def index():

  response = ""
  response +="<head> <title>Ec2 Spot Stateful Workload</title> </head>"
  response += "<h2>Here is the status of the all the EBS volumes on this EC2 instance </h2> <hr/>"

  try:
    URL = "http://169.254.169.254/latest/meta-data/spot/termination-time"
    SpotInt = requests.get(URL)
    if SpotInt.status_code == 200:
      response += "<h1>This Spot Instance Got Interruption and Termination Date is {} </h1> <hr/>".format(SpotInt.text)


    v1 = open('/home/ec2-user/volume1/state.txt', 'r')
    v2 = open('/home/ec2-user/volume2/state.txt', 'r')
    v3 = open('/home/ec2-user/volume3/state.txt', 'r')

    response += "<h3>Status of Volume1 </h3> <hr/>"
    for x in v1:
      response += "<li>{}</li>".format(x)

    #response += v1.read()
    response += "<h3>Status of Volume2 </h3> <hr/>"
    for x in v2:
      response += "<li>{}</li>".format(x)
    #response += v2.read()
    response += "<h3>Status of Volume3 </h3> <hr/>"
    for x in v3:
      response += "<li>{}</li>".format(x)
    #response += v3.read()
    v1.close()
    v2.close()
    v3.close()

  except Exception as inst:
    response += "<li>Oops !!! Failed to access my instance  metadata with error = {}</li>".format(inst)

  return response

def mountVolumes():

  os.system("mkdir -p /home/ec2-user/volume1")
  os.system("mkdir -p /home/ec2-user/volume2")
  os.system("mkdir -p /home/ec2-user/volume3")

  os.system("sudo mkfs -t xfs /dev/xvdb")
  os.system("sudo mount /dev/xvdb /home/ec2-user/volume2")

  os.system("sudo mkfs -t xfs /dev/xvdc")
  os.system("sudo mount /dev/xvdc /home/ec2-user/volume3")

  instanceId = InstanceData['instanceId']

  ec2client = boto3.client('ec2', region_name=InstanceData['region'])
  describeInstance = ec2client.describe_instances(InstanceIds=[instanceId])
  instanceData=describeInstance['Reservations'][0]['Instances'][0]
  if 'InstanceLifecycle' in instanceData.keys():
    lifecycle = instanceData['InstanceLifecycle']
  else:
    lifecycle =  "Ondemand"


  instance_type = InstanceData['instanceType']
  privateIp = InstanceData['privateIp']
  availability_zone = InstanceData['availabilityZone']
  Region = InstanceData['region']

  publicIpV4 = requests.get("http://169.254.169.254/latest/meta-data/public-ipv4")
  publicIp = publicIpV4.text

  AMIId = requests.get("http://169.254.169.254/latest/meta-data/ami-id")
  AMI = AMIId.text

  v1 = open('/home/ec2-user/volume1/state.txt', 'a')
  v2 = open('/home/ec2-user/volume2/state.txt', 'a')
  v3 = open('/home/ec2-user/volume3/state.txt', 'a')

  current_time = datetime.datetime.now()
  header = "current_time     InstanceId privateIp    publicIp        instance_type     AZ        \n"
  value = str(current_time)+"  "+instanceId+"  "+privateIp   +"  "+ publicIp +"   "+instance_type+"  "+availability_zone+"\n"

  v1.write(header)
  v1.write(value)
  v1.close()
  v2.write(header)
  v2.write(value)
  v2.close()
  v3.write(header)
  v3.write(value)
  v3.close()

if __name__ == '__main__':
  print("Starting A Simple Web Service ...")
  mountVolumes()
  app.run(port=80,host='0.0.0.0')
EOF

sudo python3 app.py