#!/bin/bash

docker_image=$1

#docker_image="gridappsd/blazegraph:develop"

[ ! -d log ] && mkdir log

logfile=~/git/bz-test/log/$( echo $docker_image | sed 's:/:_:g').log.$$
touch $logfile

cat << EOF  > /tmp/fdrs
ieee123 _C1C3E687-6FFD-C753-582B-632A27E28507
ieee123pv _E407CBB6-8C8D-9BC9-589C-AB83FBF0826D
ieee13nodeckt _49AD8E07-3BF9-A4E2-CB8F-C3722F837B62
ieee13nodecktassets _5B816B93-7A5F-B64C-8460-47C17D6E4B0F
ieee13ochre _13AD8E07-3BF9-A4E2-CB8F-C3722F837B62
ieee8500 _4F76A5F9-271D-9EB8-5E31-AA362D86F2C3
j1 _67AB291F-DCCD-31B7-B499-338206B9828F
ieee123transactive _503D6E20-F499-4CC7-8051-971E23D0BF79
final9500node _EE71F6C9-56F0-4167-A14E-7F4C71F10EAA
test9500new _AAE94E4A-2465-6F5E-37B1-3E72183A4E44
acep_psil _77966920-E1EC-EE8A-23EE-4EFD23B205BD
sourceckt _9CE150A8-8CC5-A0F9-B67E-BBD8C79D3095
EOF

#  Generating measurements files for ieee123 _C1C3E687-6FFD-C753-582B-632A27E28507
#  Generating measurements files for ieee123pv _E407CBB6-8C8D-9BC9-589C-AB83FBF0826D
#  Generating measurements files for ieee13nodeckt _49AD8E07-3BF9-A4E2-CB8F-C3722F837B62
#  Generating measurements files for ieee13nodecktassets _5B816B93-7A5F-B64C-8460-47C17D6E4B0F
#  Generating measurements files for ieee8500 _4F76A5F9-271D-9EB8-5E31-AA362D86F2C3
#  Generating measurements files for j1 _67AB291F-DCCD-31B7-B499-338206B9828F
#  Generating measurements files for ieee123transactive _503D6E20-F499-4CC7-8051-971E23D0BF79
#  Generating measurements files for test9500new _AAE94E4A-2465-6F5E-37B1-3E72183A4E44
#  Generating measurements files for acep_psil _77966920-E1EC-EE8A-23EE-4EFD23B205BD
#  Generating measurements files for sourceckt _9CE150A8-8CC5-A0F9-B67E-BBD8C79D3095


get_breakers() {
  myfdrid=$1
query="
# list measurement points for Breakers, Reclosers, LoadBreakSwitches in a selected feeder
PREFIX r:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX c:  <http://iec.ch/TC57/CIM100#>
SELECT ?cimtype ?name ?bus1 ?bus2 ?id (group_concat(distinct ?phs;separator=\"\") as ?phases) WHERE {
  SELECT ?cimtype ?name ?bus1 ?bus2 ?phs ?id WHERE {
 VALUES ?fdrid {\"${myfdrid}\"} 
 VALUES ?cimraw {c:LoadBreakSwitch c:Recloser c:Breaker}
 ?fdr c:IdentifiedObject.mRID ?fdrid.
 ?s r:type ?cimraw.
  bind(strafter(str(?cimraw),\"#\") as ?cimtype)
 ?s c:Equipment.EquipmentContainer ?fdr.
 ?s c:IdentifiedObject.name ?name.
 ?s c:IdentifiedObject.mRID ?id.
 ?t1 c:Terminal.ConductingEquipment ?s.
 ?t1 c:ACDCTerminal.sequenceNumber \"1\".
 ?t1 c:Terminal.ConnectivityNode ?cn1. 
 ?cn1 c:IdentifiedObject.name ?bus1.
 ?t2 c:Terminal.ConductingEquipment ?s.
 ?t2 c:ACDCTerminal.sequenceNumber \"2\".
 ?t2 c:Terminal.ConnectivityNode ?cn2. 
 ?cn2 c:IdentifiedObject.name ?bus2
	OPTIONAL {?swp c:SwitchPhase.Switch ?s.
 	?swp c:SwitchPhase.phaseSide1 ?phsraw.
   	bind(strafter(str(?phsraw),\"SinglePhaseKind.\") as ?phs) }
 } ORDER BY ?name ?phs
}
GROUP BY ?cimtype ?name ?bus1 ?bus2 ?id
ORDER BY ?cimtype ?name"
 
  curl -s -X POST $endpoint --data-urlencode "query=$query" \
       -H 'Accept:application/json' \
       | jq '.results | .bindings[] | .name | .value' | wc -l
       #| jq '.results '
}


get_capacitors() {
  myfdrid=$1
query="
# capacitors (does not account for 2+ unequal phases on same LinearShuntCompensator) - DistCapacitor
PREFIX r:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX c:  <http://iec.ch/TC57/CIM100#>
SELECT ?name ?basev ?nomu ?bsection ?bus ?conn ?grnd ?phs ?ctrlenabled ?discrete ?mode ?deadband ?setpoint ?delay ?monclass ?moneq ?monbus ?monphs ?id ?fdrid WHERE {
 ?s r:type c:LinearShuntCompensator.
# feeder selection options - if all commented out, query matches all feeders
VALUES ?fdrid {\"${myfdrid}\"} 
 ?s c:Equipment.EquipmentContainer ?fdr.
 ?fdr c:IdentifiedObject.mRID ?fdrid.
 ?s c:IdentifiedObject.name ?name.
 ?s c:ConductingEquipment.BaseVoltage ?bv.
 ?bv c:BaseVoltage.nominalVoltage ?basev.
 ?s c:ShuntCompensator.nomU ?nomu. 
 ?s c:LinearShuntCompensator.bPerSection ?bsection. 
 ?s c:ShuntCompensator.phaseConnection ?connraw.
   bind(strafter(str(?connraw),\"PhaseShuntConnectionKind.\") as ?conn)
 ?s c:ShuntCompensator.grounded ?grnd.
 OPTIONAL {?scp c:ShuntCompensatorPhase.ShuntCompensator ?s.
 ?scp c:ShuntCompensatorPhase.phase ?phsraw.
   bind(strafter(str(?phsraw),\"SinglePhaseKind.\") as ?phs) }
 OPTIONAL {?ctl c:RegulatingControl.RegulatingCondEq ?s.
          ?ctl c:RegulatingControl.discrete ?discrete.
          ?ctl c:RegulatingControl.enabled ?ctrlenabled.
          ?ctl c:RegulatingControl.mode ?moderaw.
           bind(strafter(str(?moderaw),\"RegulatingControlModeKind.\") as ?mode)
          ?ctl c:RegulatingControl.monitoredPhase ?monraw.
           bind(strafter(str(?monraw),\"PhaseCode.\") as ?monphs)
          ?ctl c:RegulatingControl.targetDeadband ?deadband.
          ?ctl c:RegulatingControl.targetValue ?setpoint.
          ?s c:ShuntCompensator.aVRDelay ?delay.
          ?ctl c:RegulatingControl.Terminal ?trm.
          ?trm c:Terminal.ConductingEquipment ?eq.
          ?eq a ?classraw.
           bind(strafter(str(?classraw),\"CIM100#\") as ?monclass)
          ?eq c:IdentifiedObject.name ?moneq.
          ?trm c:Terminal.ConnectivityNode ?moncn.
          ?moncn c:IdentifiedObject.name ?monbus.
          }
 ?s c:IdentifiedObject.mRID ?id. 
 ?t c:Terminal.ConductingEquipment ?s.
 ?t c:Terminal.ConnectivityNode ?cn. 
 ?cn c:IdentifiedObject.name ?bus
}
ORDER by ?name"
 
  curl -s -X POST $endpoint --data-urlencode "query=$query" \
      -H 'Accept:application/json' \
       | jq '.results | .bindings[] | .name | .value' | wc -l
}

get_fdr() {
query="
# list feeders
PREFIX r:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX c:  <http://iec.ch/TC57/CIM100#>
SELECT ?feeder ?fid 
WHERE {
     ?s r:type c:Feeder.
     ?s c:IdentifiedObject.name ?feeder.
     ?s c:IdentifiedObject.mRID ?fid.
     ?s c:Feeder.NormalEnergizingSubstation ?sub.
     ?sub c:IdentifiedObject.name ?station.
     ?sub c:IdentifiedObject.mRID ?sid.
     ?sub c:Substation.Region ?sgr.
     ?sgr c:IdentifiedObject.name ?subregion.
     ?sgr c:IdentifiedObject.mRID ?sgrid.
     ?sgr c:SubGeographicalRegion.Region ?rgn.
     ?rgn c:IdentifiedObject.name ?region.
     ?rgn c:IdentifiedObject.mRID ?rgnid.
    }
ORDER by ?feeder"

  curl -s -X POST $endpoint --data-urlencode "query=$query" \
       -H 'Accept:application/json' \
       | jq '.results | .bindings[] | .fid | .value' | sed 's/"//g'  
       #| jq '.results | .bindings[] | .feeder + " " + .fid ' | sed 's/"//g'  

}


get_houses() {
  myfdrid=$1
query="
# list houses - DistHouse
PREFIX r:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX c:  <http://iec.ch/TC57/CIM100#>
SELECT ?fdrname ?name ?parent
WHERE { 
        VALUES ?fdrid {\"${myfdrid}\"}
   ?h r:type c:House.
   ?h c:IdentifiedObject.name ?name.
   ?h c:IdentifiedObject.mRID ?id.
   ?h c:House.floorArea ?floorArea.
   ?h c:House.numberOfStories ?numberOfStories.
   OPTIONAL{?h c:House.coolingSetpoint ?coolingSetpoint.}
   OPTIONAL{?h c:House.heatingSetpoint ?heatingSetpoint.}
   OPTIONAL{?h c:House.hvacPowerFactor ?hvacPowerFactor.}
   ?h c:House.coolingSystem ?coolingSystemRaw.
        bind(strafter(str(?coolingSystemRaw),\"HouseCooling.\") as ?coolingSystem) 
   ?h c:House.heatingSystem ?heatingSystemRaw.
        bind(strafter(str(?heatingSystemRaw),\"HouseHeating.\") as ?heatingSystem)
   ?h c:House.thermalIntegrity ?thermalIntegrityRaw.
        bind(strafter(str(?thermalIntegrityRaw),\"HouseThermalIntegrity.\") as ?thermalIntegrity)
   ?h c:House.EnergyConsumer ?econ.
   ?econ c:IdentifiedObject.name ?parent.
   ?fdr c:IdentifiedObject.mRID ?fdrid.
   ?fdr c:IdentifiedObject.name ?fdrname.
   ?econ c:Equipment.EquipmentContainer ?fdr.
} ORDER BY ?fdrname ?name"
 
  curl -s -X POST $endpoint --data-urlencode "query=$query" \
       -H 'Accept:application/json' \
       | jq '.results | .bindings[] | .name | .value' | wc -l 

}

#INPUT echo "{"
#INPUT echo "  \"fdrs\" : ["
#INPUT echo -e $fdrs | while read fdr fdrid; do
  #INPUT capacitors=$(get_capacitors $fdrid)
  #INPUT houses=$(get_houses $fdrid)
  #INPUT echo "    {"
  #INPUT echo "      \"$fdr\" : \"$fdr\","
  #INPUT echo "      \"fdrid\" : \"$fdrid\","
  #INPUT echo "      \"capacitors\" : $capacitors,"
  #INPUT echo "      \"houses\" : $houses"
  #INPUT echo "    },"
#INPUT done 
#INPUT echo "  ]"
#INPUT echo "}"
#INPUT 
#INPUT exit

####################
###
docker pull $docker_image 2> /dev/null
port=9999

echo " "
echo "Starting blazegraph container $docker_image"
did=$( docker run --rm -d -p $port:8080 $docker_image )

echo "Waiting for blazegraph startup"
sleep 30

#endpoint="http://localhost:$port/bigdata/sparql"
endpoint="http://localhost:$port/bigdata/namespace/kb/sparql"

rangeCount=`curl -s -G -H 'Accept: application/xml' "${endpoint}" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
echo " "
echo "Blazegrpah rangeCount ($rangeCount)"

echo " "
echo "Getting feeders"
feeders=$(get_fdr)

echo " "
echo $feeders 

feedercount=$(echo $feeders | wc -w )
((feedercount=feedercount-1))
echo $feedercount
echo $feeders >> $logfile
echo " "

json=$(cat ~/git/bz-test/input.json)
items=$(echo $json | jq '.[] | length')
#for i in {0..8}; do
#for i in $(seq 0 $feedercount); do
for fdrid in $feeders ; do 
#  fdr=$(echo $json | jq --argjson INDEX "$i" '.fdrs[$INDEX].fdr' | sed 's/"//g')
#  fdrid=$(echo $json | jq --argjson INDEX "$i" '.fdrs[$INDEX].fdrid' | sed 's/"//g')
  #echo " "
  #echo "Verifying: $i $fdr $fdrid"

  #ref_capacitors=$(echo $json | jq --argjson INDEX "$i" '.fdrs[$INDEX].capacitors')
  #ref_houses=$(echo $json | jq --argjson INDEX "$i" '.fdrs[$INDEX].houses')


  fdr=$( grep $fdrid /tmp/fdrs | awk '{print $1}')

  capacitors=$(get_capacitors $fdrid)
  houses=$(get_houses $fdrid)
  breakers=$(get_breakers $fdrid)

  #echo "${fdr}:${fdrid}:cap:${ref_capacitors}:${capacitors}:houses:${ref_houses}:${houses}:breakers:${breakers}"
  echo "${fdr}:${fdrid}:cap:${capacitors}:houses:${houses}:breakers:${breakers}"
  echo "${fdr}:${fdrid}:cap:${ref_capacitors}:${capacitors}:houses:${ref_houses}:${houses}:breakers:${breakers}" >> $logfile
done 

echo " "
echo "Stopping blazegraph container"
did=$( docker stop $did )

echo " "
exit

