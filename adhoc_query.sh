#!/bin/bash

docker_image=$1


get_query() {
  myfdrid=$1
query="
PREFIX r: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX c: <http://iec.ch/TC57/CIM100#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?inverter_mrid ?inverter_name ?inverter_mode ?inverter_max_q ?inverter_min_q ?inverter_p ?inverter_q ?inverter_rated_s ?inverter_rated_u ?phase_mrid ?phase_name ?phase_p ?phase_q (group_concat(distinct ?phs;separator=\"\n\") as ?phases)
WHERE {
VALUES ?feeder_mrid {\"_AAE94E4A-2465-6F5E-37B1-3E72183A4E44\"}
?s r:type c:PowerElectronicsConnection.
?s c:Equipment.EquipmentContainer ?fdr.
?fdr c:IdentifiedObject.mRID ?feeder_mrid.
?s c:IdentifiedObject.mRID ?inverter_mrid.
?s c:IdentifiedObject.name ?inverter_name.
?s c:PowerElectronicsConnection.p ?inverter_p.
?s c:PowerElectronicsConnection.q ?inverter_q.
?s c:PowerElectronicsConnection.ratedS ?inverter_rated_s.
?s c:PowerElectronicsConnection.ratedU ?inverter_rated_u.
OPTIONAL {
?s c:PowerElectronicsConnection.inverterMode ?inverter_mode.
?s c:PowerElectronicsConnection.maxQ ?inverter_max_q.
?s c:PowerElectronicsConnection.minQ ?inverter_min_q.
}
OPTIONAL {
?pecp c:PowerElectronicsConnectionPhase.PowerElectronicsConnection ?s.
?pecp c:IdentifiedObject.mRID ?phase_mrid.
?pecp c:IdentifiedObject.name ?phase_name.
?pecp c:PowerElectronicsConnectionPhase.p ?phase_p.
?pecp c:PowerElectronicsConnectionPhase.q ?phase_q.
?pecp c:PowerElectronicsConnectionPhase.phase
?phsraw bind(strafter(str(?phsraw),\"SinglePhaseKind.\") as ?phs)
}
}
GROUP BY ?inverter_mrid ?inverter_name ?inverter_rated_s ?inverter_rated_u ?inverter_p ?inverter_q ?phase_mrid ?phase_name ?phase_p ?phase_q ?inverter_mode ?inverter_max_q ?inverter_min_q
ORDER BY ?inverter_mrid
"
 
  curl -s -X POST $endpoint --data-urlencode "query=$query" \
       -H 'Accept:application/json' \
       | jq '.results '
       #| jq '.results | .bindings[] | .name | .value' | wc -l
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
       | jq '.results | .bindings[] | .fid | .value'  

}


get_houses() {
  myfdrid=$1
query="
# list houses - DistHouse
PREFIX r:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX c:  <http://iec.ch/TC57/CIM100#>
SELECT ?name 
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

####################
###
docker pull $docker_image 2> /dev/null
port=9999

echo " "
echo "Starting blazegraph container $docker_image"
did=$( docker run --rm -d -p $port:8080 $docker_image )

echo "Waiting for blazegraph startup"
sleep 30

endpoint="http://localhost:$port/bigdata/sparql"

rangeCount=`curl -s -G -H 'Accept: application/xml' "${endpoint}" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
echo " "
echo "Blazegrpah rangeCount ($rangeCount)"

get_query 

echo " "
echo "Stopping blazegraph container"
did=$( docker stop $did )

echo " "
exit

