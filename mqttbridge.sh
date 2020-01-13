#!/bin/bash

timestamp=$(date +%s)

## live
path_readout=$(cat /boot/d0logging/lastreadingpath.conf)
path_obis_selection=/boot/d0logging/lorawan.conf
path_mqtt_config=/boot/d0logging/mqtt.conf
cp $path_readout $path_readout-1
/opt/j62056/run-scripts/j62056-reader -p /dev/ttyUSB0 -d 100 | tail -n +2 > $path_readout

obisSelection=$(jq -c '.obis[]' $path_mqtt_config)
mqttServer=$(jq '.host' -r $path_mqtt_config)
mqttPort=$(jq '.port' -r $path_mqtt_config)
mqttUser=$(jq '.user' -r $path_mqtt_config)
mqttPass=$(jq '.password' -r $path_mqtt_config)
serial=$(jq '."data message"."data block"[] | select(.address | contains("0.0.0")) | .value' $path_readout)

export LC_NUMERIC="en_US.UTF-8"

sJsonMQTTData="["
while read obis ; do
    line=$(jq -c '."data message"."data block"[] | select(.address=='$obis')' $path_readout)

    address=$(echo $line | jq '.address' -r); #| sed 's/[^0-9a-zA-Z]/-/g'
    value=$(echo $line | jq '.value' -r | xargs printf "%f");
    unit=$(echo $line | jq '.unit' -r );

    sJsonMQTTData="$sJsonMQTTData {\"name\":\"measurement\", \"address\": \"$address\", \"serial\":$serial, \"value\": $value, \"timestamp\": $timestamp},"
done <<<"$obisSelection"

sJsonMQTTData="${sJsonMQTTData::-1}]"

## debug output
#echo $sJsonMQTTData

## send live data
mosquitto_pub -h $mqttServer -t sensors/d0logging -m "$sJsonMQTTData" -p $mqttPort -u $mqttUser -P $mqttPass
