#!/bin/bash
source /cvmfs/cms.cern.ch/cmsset_default.sh

#ConfigRelease=CMSSW_10_0_0_pre1
ConfigRelease=CMSSW_9_3_1
RunningRelease=${ConfigRelease}

echo "================= PB: Starting cmssw environment prepration ====================" | tee -a job.log

export SCRAM_ARCH=slc6_amd64_gcc630
if [ -r ${ConfigRelease}/src ] ; then 
 echo release ${ConfigRelease} already exists
else
scram p CMSSW ${ConfigRelease}
fi
cd ${ConfigRelease}/src
eval `scram runtime -sh`

INPUT_FRAGMENT=externalLHEProducer_and_PYTHIA8_Hadronizer_cff.py

ZDMASS=3
NOFJET=0
EPSILON=1e-2
GLOBALTAG=93X_mc2017_realistic_v3
## NEVENTS per file
NEVENTS=1000

echo "================= PB: Input Parameters ========================================"  | tee -a job.log
echo "ZDMASS:"		$ZDMASS
echo "NOFJET:" 		$NOFJET
echo "EPSILON:" 	$EPSILON
echo "GLOBALTAG:" 	$GLOBALTAG
echo "NEVENTS:" 	$NEVENTS


GRIDPACK_NAME=HAHM_variablesw_v3_MZd${ZDMASS}_eps${EPSILON}.tar.xz

echo "================= PB: Gridpack name ========================================"  | tee -a job.log
echo $GRIDPACK_NAME

echo "================= PB: Preparing the configs from fragments ====================" | tee -a job.log

JOB_LABEL=zd${NOFJET}j_MZd${ZDMASS}_eps${EPSILON}
OUTPUT_FRAGMENT=${INPUT_FRAGMENT/_cff.py/}_${JOB_LABEL}_cff.py


cd ../../
sed -e s#GRIDPACKNAME#${GRIDPACK_NAME}#g  ${INPUT_FRAGMENT} > ${ConfigRelease}/src/${OUTPUT_FRAGMENT}
sed -i s#THISDIR#${PWD}#g ${ConfigRelease}/src/${OUTPUT_FRAGMENT}
cd -

[ -d Configuration/GenProduction/python/ThirteenTeV/Hadronizer ] || mkdir -p Configuration/GenProduction/python/ThirteenTeV/Hadronizer
cp ${OUTPUT_FRAGMENT} Configuration/GenProduction/python/ThirteenTeV/Hadronizer/${OUTPUT_FRAGMENT}
[ -s Configuration/GenProduction/python/ThirteenTeV/Hadronizer/${OUTPUT_FRAGMENT} ] || exit $?;

echo "================= PB: Compiling fragments from release ====================" | tee -a job.log

scram b
cd ../../

# Renaming externalLHEProducer_and_PYTHIA8_Hadronizer_cff.py
CONFIG_TO_RUN=${OUTPUT_FRAGMENT/_cff/_LHE-GEN-SIM_cfg}

echo "================= PB: Running cmsDriver ====================" | tee -a job.log

# Make sure --fileout file:<FILE_NAME> is exactly how you want it; must match crab_GEN-SIM.py and step1_GEN-SIM_cfg.py
echo cmsDriver.py Configuration/GenProduction/python/ThirteenTeV/Hadronizer/${OUTPUT_FRAGMENT} --fileout file:${JOB_LABEL}_LHE-GEN-SIM.root --mc --eventcontent RAWSIM,LHE --datatier GEN-SIM,LHE --conditions ${GLOBALTAG}  --beamspot Realistic25ns13TeVEarly2017Collision --step LHE,GEN,SIM --nThreads 8 --geometry DB:Extended --era Run2_2017 --python_filename ${CONFIG_TO_RUN} --no_exec  -n ${NEVENTS} || exit $? ; 
cmsDriver.py Configuration/GenProduction/python/ThirteenTeV/Hadronizer/${OUTPUT_FRAGMENT} --fileout file:${JOB_LABEL}_LHE-GEN-SIM.root --mc --eventcontent RAWSIM,LHE --datatier GEN-SIM,LHE --conditions ${GLOBALTAG}  --beamspot Realistic25ns13TeVEarly2017Collision --step LHE,GEN,SIM --nThreads 1 --geometry DB:Extended --era Run2_2017 --python_filename ${CONFIG_TO_RUN} --no_exec -n ${NEVENTS} || exit $? ; 

echo "================= PB: Dumping config file ====================" | tee -a job.log
cat ${CONFIG_TO_RUN}

# ========= Now run the LHE =============
echo "================= PB: Now start the setup for running the LHE ====================" | tee -a job.log


echo "================= PB: CMSRUN starting jobNum=$1 ====================" | tee -a job.log
echo "================= PB: CMSRUN setting up " ${RunningRelease} " ===================="| tee -a job.log
if [ -r ${RunningRelease}/src ] ; then 
     echo release ${RunningRelease} already exists
 else
     scram p CMSSW ${RunningRelease}
 fi

BASE=$PWD
NUM=100
echo "working directory: $PWD"

cd ${RunningRelease}/src
eval `scram runtime -sh`

scram b
cd ../../

echo "================= PB: CMSRUN starting Step 1 ====================" | tee -a job.log
echo cmsRun -e -j FrameworkJobReport.xml -p $CONFIG_TO_RUN 
cmsRun -e -j FrameworkJobReport.xml -p $CONFIG_TO_RUN 
#cmsRun -j FrameworkJobReport.xml -p $CONFIG_TO_RUN jobNum=$1

ls -ltr
echo "================== PB: Copying the lhe to eos ====================" | tee -a job.log

# if [ -s lheevent/cmsgrid_final.lhe ];
#   do 
# 
#   xrdcp lheevent/cmsgrid_final.lhe 'root://eoscms.cern.ch//eos/cms/store/user/bortigno/mc_genproduction/darkphoton/'+'lhe_files/'+$JOB_LABEL+'_cmsgrid_final_'+$1+'.lhe'
#   rm -rf lheevent 
# else
#   xrdcp cmsgrid_final.lhe 'root://eoscms.cern.ch//eos/cms/store/user/bortigno/mc_genproduction/darkphoton/'+'lhe_files/'+$JOB_LABEL+'_cmsgrid_final_'+$1+'.lhe'
#   rm cmsgrid_final.lhe
# 
# 
#rm -v *.root  
