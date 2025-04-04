function bits = HelperGPSNAVDataEncode(cfg)
%HelperGPSNAVDataEncode GPS CNAV/LNAV Navigation data bits generation
%
%   Note: This is a helper and its API and/or functionality may change
%   in subsequent releases.
%
%   BITS = HelperGPSNAVDataEncode(CFG) generates encoded bit stream BITS
%   which contains data bits for GPS legacy navigation (LNAV) or civil
%   Navigation (CNAV) data transmission. CFG is a configuration object of
%   type <a href="matlab:help('HelperGPSNavigationConfig')">HelperGPSNavigationConfig</a>. The data bits are generated from the
%   fields that go into legacy navigation (LNAV) GPS data. Each of these
%   fields are available in the config object, CFG. The frame structure of
%   LNAV data, CNAV data, CNAV2 data and the properties that are encoded into the frame
%   are given in Appendix II, Appendix III of IS-GPS-200 [1], and section
%   3.5 of IS-GPS-800 [2] respectively.
%
%   References:
%    [1] IS-GPS-200L. "NAVSTAR GPS Space Segment/Navigation User Segment
%        Interfaces." GPS Enterprise Space & Missile Systems Center (SMC) -
%        LAAFB, May 14, 2020.
%
%    [2] IS-GPS-800, Rev: J. NAVSTAR GPS Space Segment/User segment L1C
%        Interfaces. Aug 22, 2022; Code Ident: 66RP1.

%   Copyright 2021-2023 The MathWorks, Inc.

if strcmp(cfg.SignalType,'CNAV')
    bits = GPSCNAVDataEncode(cfg);
elseif strcmp(cfg.SignalType,'LNAV')
    bits = GPSLNAVDataEncode(cfg);
else % strcmp(cfg.SignalType,'CNAV2')
    bits = GPSCNAV2DataEncode(cfg);
end
end

function navData = GPSLNAVDataEncode(cfg)
%GPSLNAVDataEncode Navigation data bits generation for LNAV GPS
%
%   LNAVBITS = GPSLNAVDataEncode(CFG) generates encoded bit stream
%   LNAVBITS which contains data bits for legacy GPS transmission. CFG is
%   a configuration object of type <a href="matlab:help('HelperGPSNavigationConfig')">HelperGPSNavigationConfig</a>. The data bits
%   are generated from the fields that go into legacy navigation (LNAV) GPS
%   data. Each of these fields are available in the config object, CFG.
%   The frame structure of LNAV data and the properties that are encoded
%   into the frame are given in Appendix II of IS-GPS-200 [1].

% Read the almanac file
[~, almWeekNum, almTimeOfApplicability, almStruct] = ...
    matlabshared.internal.gnss.readSEMAlmanac(cfg.AlmanacFileName);

subframeLength = 300; % Bits
NumSubframes   = 5;
frameIndices = cfg.FrameIndices;
numFrames = length(frameIndices);
navData = zeros(numFrames*NumSubframes*subframeLength, 1);

for iFrame = 1:numFrames
    cfg.PageID = mod(cfg.FrameIndices(iFrame)-1, 25)+1;
    for iSubframe = 1:NumSubframes
        cfg.SubframeID = iSubframe; % This information is encoded in every subframe. Hence, need to be updated for every subframe
        switch iSubframe
            case 1
                subframe = subframe1(cfg);
            case 2
                subframe = subframe2(cfg);
            case 3
                subframe = subframe3(cfg);
            case 4
                subframe = subframe4(cfg,almStruct,almTimeOfApplicability);
            case 5
                subframe = subframe5(cfg,almStruct,almTimeOfApplicability,almWeekNum);
        end
        cfg.HOWTOW = cfg.HOWTOW + 1; % The TOW in HOW increments by 1 for every 6 sec.
        startIDX = (iFrame-1)*(1500) + 1 + (iSubframe-1)*300;
        endIDX = (iFrame-1)*(1500) + iSubframe*300;
        navData(startIDX:endIDX) = subframe;
    end
end
end

function word = HandoverWord(howdata)
%HANDOVERWORD generates the handover word (HOW)
%   WORD = HandoverWord(HOWDATA) generates the 30 bits for the handover
%   word according to the parameters given in the structure HOWDATA.
%   Following are the parameters in the structure HOWDATA:
%
%   HOWTOW        - time of week in the handover word. LSB is 6 sec
%   AlertFlag     - Alert flag
%   AntiSpoofFlag - Anti-spoofing flag. If set, then anti-spoofing is on
%   SubframeID    - Subframe ID (1 to 5)

towBin = num2bits(howdata.HOWTOW, 17, 1);
bit18Alert = howdata.AlertFlag;
bit19AS = howdata.AntiSpoofFlag;
subframeIDBin = num2bits(howdata.SubframeID, 3, 1);
data = [towBin; bit18Alert; bit19AS; subframeIDBin];
wordNumber = 2;
word = gpsLNavWordEnc(data,wordNumber);
end

function reservedWord = ReservedWord(wordNumber)
% Generate a word whose 24 bits data elements are all zeros and have valid
% parity bits. As parity calculation depends on previous word, parity is not
% always zeros even if 24 bits in the word is zero.

data = zeros(24, 1);
reservedWord = gpsLNavWordEnc(data,wordNumber);
end

function subframe = subframe1(opts)
% Generate 300 bits of GPS LNAV subframe1 data from the parameters given in
% 'opts' input structure

word1 = TLMWord(opts); % Having the default values of TLM word for speed
word2 = HandoverWord(opts);

wordNumber = 3;

weekNumber = mod(opts.WeekNumber,1024);
weekNumberBin = num2bits(weekNumber,10, 1);

if strcmp(opts.CodesOnL2,'P-code')
    codesOnL2Bin = [0;1];
else % C/A-code
    codesOnL2Bin = [1;0];
end

uraVal = opts.URAID;
uraValBin = num2bits(uraVal, 4, 1);

svHealthBin = num2bits(opts.SVHealth, 6, 1);

iodc = opts.IssueOfDataClock;
iodcBin = num2bits(iodc, 10, 1);

data = [weekNumberBin; codesOnL2Bin; uraValBin; svHealthBin; iodcBin(1:2)];
word3 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 4;
data = [opts.L2PDataFlag; zeros(23, 1)];
word4 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 5;
word5 = ReservedWord(wordNumber);

wordNumber = 6;
word6 = ReservedWord(wordNumber);

wordNumber = 7;

T_GDBin = num2bits(opts.GroupDelayDifferential, 8, 2^-31);

data = [zeros(16, 1); T_GDBin];
word7 = gpsLNavWordEnc(data, wordNumber);

wordNumber = 8;

tOC = opts.ReferenceTimeOfClock;
tOCBin = num2bits(tOC, 16, 2^4);

data = [iodcBin(3:10); tOCBin];
word8 = gpsLNavWordEnc(data,wordNumber);

af2 = opts.SVClockCorrectionCoefficients(3);
af1 = opts.SVClockCorrectionCoefficients(2);
af0 = opts.SVClockCorrectionCoefficients(1);

wordNumber = 9;

scaleFactor = 2^(-55);
af2Bin = num2bits(af2, 8, scaleFactor);

scaleFactor = 2^(-43);
af1NumBits = 16;
af1Bin = num2bits(af1, af1NumBits, scaleFactor);

data = [af2Bin; af1Bin];
word9 = gpsLNavWordEnc(data,wordNumber);

wordNumber=10;

scaleFactor = 2^(-31);
af0NumBits = 22;
af0Bin = num2bits(af0, af0NumBits, scaleFactor);

data = af0Bin;
word10 = gpsLNavWordEnc(data,wordNumber);

subframe = [word1; word2; word3; word4; word5; word6; word7; word8; word9; word10];

end

function subframe = subframe2(opts)
% Generate 300 bits of GPS LNAV subframe2 data from the parameters given in
% 'opts' and 'ephemeris' input structures

word1 = TLMWord(opts); % Having the default values of TLM word for speed
word2 = HandoverWord(opts);

wordNumber = 3;

iode = opts.IssueOfDataEphemeris;
iodeBin = num2bits(iode,8,1);


crs = opts.HarmonicCorrectionTerms(3);
cus = opts.HarmonicCorrectionTerms(5);
cuc = opts.HarmonicCorrectionTerms(6);
scaleFactor = 2^(-5);
sinHrmcCorrection = num2bits(crs,16,scaleFactor);

data = [iodeBin; sinHrmcCorrection];
word3 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 4;

meanMotionDiff = opts.MeanMotionDifference;
meanMotionDiffBin = num2bits(meanMotionDiff, 16, 2^(-43));

meanAnom = opts.MeanAnomaly;
meanAnomBin = num2bits(meanAnom, 32, 2^(-31));

data = [meanMotionDiffBin; meanAnomBin(1:8)];
word4 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 5;
data = meanAnomBin(9:32);
word5 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 6;

scaleFactor = 2^(-29);
cucNumBits = 16;
cucBin = num2bits(cuc, cucNumBits, scaleFactor);

eccen = opts.Eccentricity;
scaleFactor = 2^(-33);
eccenNumBits = 32;
eccenBin = num2bits(eccen, eccenNumBits, scaleFactor);

data = [cucBin; eccenBin(1:8)];
word6 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 7;
data = eccenBin(9:32);
word7 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 8;

scaleFactor = 2^(-29);
cusNumBits = 16;
cusBin = num2bits(cus, cusNumBits, scaleFactor);

sqRootA = sqrt(opts.SemiMajorAxisLength);
scaleFactor = 2^(-19);
sqRootANumBits = 32;
sqRootABin = num2bits(sqRootA, sqRootANumBits, scaleFactor);

data = [cusBin; sqRootABin(1:8)];
word8 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 9;
data = sqRootABin(9:32);
word9 = gpsLNavWordEnc(data,wordNumber);

wordNumber=10;

toe = opts.ReferenceTimeOfEphemeris;
scaleFactor = 2^(4);
toeNumBits = 16;
toeBin = num2bits(toe, toeNumBits, scaleFactor);

AODO = opts.AgeOfDataOffset;
AODOBin = num2bits(AODO, 5, 900);

data =[toeBin; opts.FitIntervalFlag; AODOBin];
word10 = gpsLNavWordEnc(data,wordNumber);

subframe = [word1; word2; word3; word4; word5; word6; word7; word8; word9; word10];
end


function subframe = subframe3(opts)
% Generate 300 bits of GPS LNAV subframe3 data from the parameters given in
% 'opts' and 'ephemeris' input structures

word1 = TLMWord(opts); % Having the default values of TLM word for speed
word2 = HandoverWord(opts);

wordNumber = 3;

cis = opts.HarmonicCorrectionTerms(1);
cic = opts.HarmonicCorrectionTerms(2);
crc = opts.HarmonicCorrectionTerms(4);
scaleFactor = 2^(-29);
cicNumBits = 16;
cicBin = num2bits(cic, cicNumBits, scaleFactor);

longOrbitPlane = opts.LongitudeOfAscendingNode;
scaleFactor = 2^(-31);
longOrbitPlaneNumBits =32;
longOrbitPlaneBin = num2bits(longOrbitPlane,longOrbitPlaneNumBits,scaleFactor);

data = [cicBin; longOrbitPlaneBin(1:8)];
word3 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 4;
data = longOrbitPlaneBin(9:32);
word4 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 5;

scaleFactor = 2^(-29);
cisNumBits = 16;
cisBin = num2bits(cis, cisNumBits, scaleFactor);

refIncAngle = opts.Inclination;
scaleFactor = 2^(-31);
refIncAngleNumBits = 32;
refIncAngleBin = num2bits(refIncAngle, refIncAngleNumBits, scaleFactor);

data = [cisBin; refIncAngleBin(1:8)];
word5 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 6;
data = refIncAngleBin(9:32);
word6 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 7;

scaleFactor = 2^(-5);
crcNumBits = 16;
crcBin = num2bits(crc,crcNumBits,scaleFactor);

argPerig = opts.ArgumentOfPerigee;
argPerigNumBits = 32;
scaleFactor = 2^(-31);
argPerigBin = num2bits(argPerig,argPerigNumBits,scaleFactor);

data = [crcBin; argPerigBin(1:8)];
word7 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 8;
data = argPerigBin(9:32);
word8 = gpsLNavWordEnc(data,wordNumber);

wordNumber = 9;

rorAscension = opts.RateOfRightAscension;
rorAscensionNumBits = 24;
scaleFactor = 2^(-43);
rorAscensionBin = num2bits(rorAscension,rorAscensionNumBits,scaleFactor);

data = rorAscensionBin;
word9 = gpsLNavWordEnc(data,wordNumber);

wordNumber=10;

iode = opts.IssueOfDataEphemeris;
iodeNumBits = 8;
iodeBin = num2bits(iode, iodeNumBits, 1);

idot = opts.InclinationRate;
idotNumBits = 14;
scaleFactor = 2^(-43);
idotBin = num2bits(idot, idotNumBits, scaleFactor);

data =[iodeBin; idotBin];
word10 = gpsLNavWordEnc(data,wordNumber);

subframe = [word1; word2; word3; word4; word5; word6; word7; word8; word9; word10];
end

function subframe = subframe4(opts,almanac,almTimeOfApplicability)
% Generate 300 bits of GPS LNAV subframe4 data from the parameters given in
% 'opts' and 'almanac' input structures

word1 = TLMWord(opts); % Having the default values of TLM word for speed
word2 = HandoverWord(opts);

dataid = [0; 1];
subframe4SVID = [57; 25; 26; 27; 28; 57; 29; 30; 31; 32; 57; 62; 52; 53;...
    54; 57; 55; 56; 58; 59; 57; 60; 61; 62; 63];

switch opts.PageID
    case {2, 3, 4, 5, 7, 8, 9, 10} % Almanac data for SV 25 through 32
        prnidx = subframe4SVID(opts.PageID);
        words = almstruct2bits(almanac,prnidx,almTimeOfApplicability);
    case {1, 6, 11, 12, 14, 15, 16, 19, 20, 21, 22, 23, 24} % Reserved messages
        svid = subframe4SVID(opts.PageID);
        svidBin = num2bits(svid, 6, 1);

        wordNum = 3;

        data = [dataid; svidBin; zeros(16, 1)];
        word3 = gpsLNavWordEnc(data, wordNum);
        words = [word3; zeros(210, 1)];

        for iword = 4:10
            if iword~=10
                data = zeros(24, 1);
            else
                data = zeros(22, 1);
            end
            words((iword-3)*30+1:(iword-2)*30) = gpsLNavWordEnc(data, iword);
        end
    case 13 % NMCT data
        svid = subframe4SVID(opts.PageID);
        svidBin = num2bits(svid, 6, 1);

        wordNum = 3;

        ai = opts.NMCTAvailabilityIndicator;
        aiBin = num2bits(ai, 2, 1);

        nmctBin = NMCT2Bin(opts.NMCTERD);

        data = [dataid; svidBin; aiBin; nmctBin(1, :)'; nmctBin(2,:)'; nmctBin(3, 1:2)'];
        word3 = gpsLNavWordEnc(data, wordNum);

        wordNum = 4;
        data = [nmctBin(3, 3:6)'; nmctBin(4,:)'; nmctBin(5,:)'; nmctBin(6,:)'; nmctBin(7,1:2)'];
        word4 = gpsLNavWordEnc(data, wordNum);

        wordNum = 5;
        data = [nmctBin(7,3:6)'; nmctBin(8,:)'; nmctBin(9,:)'; nmctBin(10,:)'; nmctBin(11,1:2)'];
        word5 = gpsLNavWordEnc(data, wordNum);

        wordNum = 6;
        data = [nmctBin(11,3:6)'; nmctBin(12,:)'; nmctBin(13,:)'; nmctBin(14,:)'; nmctBin(15,1:2)'];
        word6 = gpsLNavWordEnc(data, wordNum);

        wordNum = 7;
        data = [nmctBin(15,3:6)'; nmctBin(16,:)'; nmctBin(17,:)'; nmctBin(18,:)'; nmctBin(19,1:2)'];
        word7 = gpsLNavWordEnc(data, wordNum);

        wordNum = 8;
        data = [nmctBin(19,3:6)'; nmctBin(20,:)'; nmctBin(21,:)'; nmctBin(22,:)'; nmctBin(23,1:2)'];
        word8 = gpsLNavWordEnc(data, wordNum);

        wordNum = 9;
        data = [nmctBin(23,3:6)'; nmctBin(24,:)'; nmctBin(25,:)'; nmctBin(26,:)'; nmctBin(27,1:2)'];
        word9 = gpsLNavWordEnc(data, wordNum);

        wordNum = 10;
        data = [nmctBin(27,3:6)'; nmctBin(28,:)'; nmctBin(29,:)'; nmctBin(30,:)'];
        word10 = gpsLNavWordEnc(data, wordNum);

        words = [word3; word4; word5; word6; word7; word8; word9; word10];
    case 17 % Text message
        svid = subframe4SVID(opts.PageID);
        svidBin = num2bits(svid, 6, 1);
        numCharInMessage = 22;
        fullText = char(opts.TextMessage(:).');
        if length(fullText) >= numCharInMessage
            text = fullText(1:numCharInMessage);
        else
            text = [fullText, repmat(' ',1, numCharInMessage-length(fullText))];
        end
        TempBits = int2bit(double(text),8);

        wordNum = 3;

        data = [dataid; svidBin; reshape(TempBits(:,1:2),[],1)];
        word3 = gpsLNavWordEnc(data, wordNum);

        wordNum = 4;
        data = reshape(TempBits(:,3:5),[],1);
        word4 = gpsLNavWordEnc(data, wordNum);

        wordNum = 5;
        data = reshape(TempBits(:,6:8),[],1);
        word5 = gpsLNavWordEnc(data, wordNum);

        wordNum = 6;
        data = reshape(TempBits(:,9:11),[],1);
        word6 = gpsLNavWordEnc(data, wordNum);

        wordNum = 7;
        data = reshape(TempBits(:,12:14),[],1);
        word7 = gpsLNavWordEnc(data, wordNum);

        wordNum = 8;
        data = reshape(TempBits(:,15:17),[],1);
        word8 = gpsLNavWordEnc(data, wordNum);

        wordNum = 9;
        data = reshape(TempBits(:,18:20),[],1);
        word9 = gpsLNavWordEnc(data, wordNum);

        wordNum = 10;
        data = [reshape(TempBits(:,21:22),[],1); zeros(6,1)];
        word10 = gpsLNavWordEnc(data, wordNum);

        words = [word3; word4; word5; word6; word7; word8; word9; word10];
    case 18 % Ionospheric and UTC data
        ionosphere = opts.Ionosphere;
        utc = opts.UTC;

        wordNum = 3;

        svid = subframe4SVID(opts.PageID);
        svidBin = num2bits(svid, 6, 1);

        alpha0 = ionosphere.Alpha(1);
        alpha0Bin = num2bits(alpha0, 8, 2^-30);
        alpha1 = ionosphere.Alpha(2);
        alpha1Bin = num2bits(alpha1, 8, 2^-27);

        data = [dataid; svidBin; alpha0Bin; alpha1Bin];
        word3 = gpsLNavWordEnc(data, wordNum);

        wordNum = 4;

        alpha2 = ionosphere.Alpha(3);
        alpha2Bin = num2bits(alpha2, 8, 2^-24);

        alpha3 = ionosphere.Alpha(4);
        alpha3Bin = num2bits(alpha3, 8, 2^-24);

        beta0 = ionosphere.Beta(1);
        beta0Bin = num2bits(beta0, 8, 2^11);

        data = [alpha2Bin; alpha3Bin; beta0Bin];
        word4 = gpsLNavWordEnc(data, wordNum);

        wordNum = 5;

        beta1 = ionosphere.Beta(2);
        beta1Bin = num2bits(beta1, 8, 2^14);

        beta2 = ionosphere.Beta(3);
        beta2Bin = num2bits(beta2, 8, 2^16);

        beta3 = ionosphere.Beta(4);
        beta3Bin = num2bits(beta3, 8, 2^16);

        data = [beta1Bin; beta2Bin; beta3Bin];
        word5 = gpsLNavWordEnc(data, wordNum);

        wordNum = 6;

        A1 = utc.UTCTimeCoefficients(2);
        A1Bin = num2bits(A1, 24, 2^-50);

        word6 = gpsLNavWordEnc(A1Bin, wordNum);

        wordNum = 7;

        A0 = utc.UTCTimeCoefficients(1);
        A0Bin = num2bits(A0, 32, 2^-30);

        word7 = gpsLNavWordEnc(A0Bin(1:24), wordNum);

        wordNum = 8;

        tot = utc.ReferenceTimeUTCData;
        totBin = num2bits(tot, 8, 2^12);

        WNt  = utc.TimeDataReferenceWeekNumber;
        WNtBin = num2bits(WNt, 8, 1);

        data = [A0Bin(25:32); totBin; WNtBin];
        word8 = gpsLNavWordEnc(data, wordNum);

        wordNum = 9;

        DeltLS = utc.PastLeapSecondCount;
        DeltLSBin = num2bits(DeltLS, 8, 1);

        WNLSF = utc.LeapSecondReferenceWeekNumber;
        WNLSFBin = num2bits(WNLSF, 8, 1);

        DN = utc.LeapSecondReferenceDayNumber;
        DNBin = num2bits(DN, 8, 1);

        data = [DeltLSBin; WNLSFBin; DNBin];
        word9 = gpsLNavWordEnc(data, wordNum);

        wordNum = 10;

        DeltLSF = utc.FutureLeapSecondCount;
        DeltLSFBin = num2bits(DeltLSF, 8, 1);

        data = [DeltLSFBin; zeros(14, 1)];
        word10 = gpsLNavWordEnc(data, wordNum);

        words = [word3; word4; word5; word6; word7; word8; word9; word10];
    case 25 % A-S flags/ SV configurations for 32 SVs, plus SV health for SV 25 through 32

        svid = subframe4SVID(opts.PageID);
        svidBin = num2bits(svid, 6, 1);

        for iSV = 1:32 % Generate SVConfig for each PRN
            almdataidx = [almanac(:).PRNNumber]==iSV;
            if nnz(almdataidx)
                svconfig = almanac(almdataidx).SatelliteConfiguration;
            else
                svconfig = 15;
            end
            svconfigBin = num2bits(svconfig, 4, 1); %#ok<NASGU>
            varName = ['svconfigBin' num2str(iSV)];
            eval([varName '=svconfigBin;']);
        end

        for iSV = 25:32 % Generate SVHealth for each PRN
            almdataidx = [almanac(:).PRNNumber]==iSV;
            if nnz(almdataidx)
                svhealth = almanac(almdataidx).SatelliteHealth;
            else
                svhealth = 63;
            end
            svhealthBin = num2bits(svhealth, 6, 1); %#ok<NASGU>
            varName = ['svhealthBin' num2str(iSV)];
            eval([varName '=svhealthBin;']);
        end

        wordNum = 3;

        data = [dataid; svidBin; svconfigBin1; svconfigBin2; svconfigBin3; svconfigBin4];
        word3 = gpsLNavWordEnc(data, wordNum);

        for iword = 4:7
            varNum = (iword-4)*6+5:(iword-3)*6+4;
            eval(['data = [svconfigBin' num2str(varNum(1)) ';svconfigBin' num2str(varNum(2))...
                ';svconfigBin' num2str(varNum(3)) ';svconfigBin' num2str(varNum(4))...
                ';svconfigBin' num2str(varNum(5)) ';svconfigBin' num2str(varNum(6)) '];']);
            eval(['word' num2str(iword) '=gpsLNavWordEnc(data, iword);']);
        end

        wordNum = 8;

        data = [svconfigBin29; svconfigBin30; svconfigBin31; svconfigBin32;...
            zeros(2,1); svhealthBin25];
        word8 = gpsLNavWordEnc(data, wordNum);

        wordNum = 9;

        data = [svhealthBin26; svhealthBin27; svhealthBin28; svhealthBin29];
        word9 = gpsLNavWordEnc(data, wordNum);

        wordNum = 10;

        data = [svhealthBin30; svhealthBin31; svhealthBin32; zeros(4, 1)];
        word10 = gpsLNavWordEnc(data, wordNum);

        words = [word3; word4; word5; word6; word7; word8; word9; word10]; %#ok
end

subframe = [word1; word2; words];
end

function subframe = subframe5(opts,almanac,almTimeOfApplicability,almWeekNum)
% Generate 300 bits of GPS LNAV subframe5 data from the parameters given in
% 'opts' and 'almanac' input structures

word1 = TLMWord(opts); % Having the default values of TLM word for speed
word2 = HandoverWord(opts);

dataid = [0; 1];
subframe5SVID = [(1:24)'; 51];

caseName = 'Empty';
if ismember(opts.PageID, 1:24)
    caseName = 'almanac';
elseif opts.PageID==25
    caseName = 'SVData';
end

switch caseName
    case 'almanac' % Almanac data for SV 25 through 32
        prnidx = subframe5SVID(opts.PageID);
        words = almstruct2bits(almanac,prnidx,almTimeOfApplicability);
    case 'SVData'
        wordNum = 3;

        svid = subframe5SVID(opts.PageID);
        svidBin = num2bits(svid, 6, 1);

        toa = almTimeOfApplicability;
        toaBin = num2bits(toa, 8, 2^12);

        WNa = mod(almWeekNum, 2^8);
        WNaBin = num2bits(WNa, 8, 1);

        data = [dataid; svidBin; toaBin; WNaBin];
        word3 = gpsLNavWordEnc(data, wordNum);

        for iSV = 1:24 % Generate SVHealth for each PRN
            almdataidx = [almanac(:).PRNNumber]==iSV;
            if nnz(almdataidx)
                svhealth = almanac(almdataidx).SatelliteHealth;
            else
                svhealth = 63;
            end
            svhealthBin = num2bits(svhealth, 6, 1); %#ok<NASGU>
            varName = ['svhealthBin' num2str(iSV)];
            eval([varName '=svhealthBin;']);
        end

        for iword = 4:9
            varNum = (iword-4)*4+1:(iword-3)*4;
            eval(['data = [svhealthBin' num2str(varNum(1)) ';svhealthBin' num2str(varNum(2))...
                ';svhealthBin' num2str(varNum(3)) ';svhealthBin' num2str(varNum(4)) '];']);
            eval(['word' num2str(iword) '=gpsLNavWordEnc(data, iword);']);
        end

        wordNum =  10;
        data = zeros(22, 1);
        word10 = gpsLNavWordEnc(data, wordNum);

        words = [word3; word4; word5; word6; word7; word8; word9; word10];
end

subframe = [word1; word2; words];

end

function bits = almstruct2bits(almanac,PRNID,almTimeOfApplicability)
%Converts one PRNID almanac data to bits from structure
%   BITS = almstruct2bits(ALMANAC,PRNID,almTimeOfApplicability)
%   converts almanac which is in a structure to bits in word 3 through 10
%   along with proper parity for LNAV data. This is useful in both subframe
%   4 and subframe 5.
%
% Parameters in ALMANAC
%   PRNNumber
%   SVN
%   AverageURANumber
%   Eccentricity
%   InclinationOffset
%   RateOfRightAscension
%   SqrtOfSemiMajorAxis
%   GeographicLongitudeOfOrbitalPlane
%   ArgumentOfPerigee
%   MeanAnomaly
%   ZerothOrderClockCorrection
%   FirstOrderClockCorrection
%   SatelliteHealth % 6 bits with MSB value to be health status flag
%   NAVDataHealth   % 3 bit NAV data health indications. If not specified,
%                   % default value is 3 zero bits.
%   SatelliteConfiguration

wordNum = 3;

dataid = [0; 1];
almdataidx = [almanac(:).PRNNumber]==PRNID;
if nnz(almdataidx)==0
    % Where PRNID is not found, then that PRNID satellite is a dummy
    % satellite and initialize the almanac message with alternating ones
    % and zeros and have the SV ID as zero.
    svidBin = zeros(6, 1);

    data = [dataid; svidBin; repmat([1; 0], 8, 1)];
    word3 = gpsLNavWordEnc(data,wordNum);

    wordNum = 4;
    data = repmat([1; 0], 12, 1);
    word4 = gpsLNavWordEnc(data,wordNum);

    wordNum = 5;
    word5 = gpsLNavWordEnc(data,wordNum);

    wordNum = 6;
    word6 = gpsLNavWordEnc(data,wordNum);

    wordNum = 7;
    word7 = gpsLNavWordEnc(data,wordNum);

    wordNum = 8;
    word8 = gpsLNavWordEnc(data,wordNum);

    wordNum = 9;
    word9 = gpsLNavWordEnc(data,wordNum);

    wordNum = 10;
    data = repmat([1; 0], 11, 1);
    word10 = gpsLNavWordEnc(data,wordNum);
else
    svidBin = num2bits(almanac(almdataidx).PRNNumber, 6, 1);

    e = almanac(almdataidx).Eccentricity;
    eBin = num2bits(e, 16, 2^-21);

    data = [dataid; svidBin; eBin];
    word3 = gpsLNavWordEnc(data,wordNum);

    wordNum = 4;

    toa = almTimeOfApplicability;
    toaBin = num2bits(toa, 8, 2^(12));

    deli = almanac(almdataidx).InclinationOffset; % delta_i is a correction to inclination term with reference to 0.3semicircles
    deliBin = num2bits(deli, 16, 2^(-19));

    data = [toaBin; deliBin];
    word4 = gpsLNavWordEnc(data,wordNum);

    wordNum = 5;

    OmegaDot = almanac(almdataidx).RateOfRightAscension;
    OmegaDotBin = num2bits(OmegaDot, 16, 2^(-38));

    % SVHealth in almanac should be of 8 bits but SEM only gives
    % information of 5 bits. Other three bits is data health which is not
    % specified in SEM almanac format. So, if a user specifies data health
    % value, it will be taken. Else, data health will be three zero bits.
    if isfield(almanac, 'NAVDataHealth')
        datahealth = almanac(almdataidx).NAVDataHealth;
        datahealthBin = num2bits(datahealth, 3, 1);
    else
        datahealthBin = zeros(3, 1);
    end

    svhealth = almanac(almdataidx).SatelliteHealth;
    svhealthBin = num2bits(svhealth, 6, 1);

    data = [OmegaDotBin; datahealthBin; svhealthBin(2:end)];
    word5 = gpsLNavWordEnc(data,wordNum);

    wordNum = 6;

    sqrtA = almanac(almdataidx).SqrtOfSemiMajorAxis;
    sqrtABin = num2bits(sqrtA, 24, 2^(-11));

    word6 = gpsLNavWordEnc(sqrtABin, wordNum);

    wordNum = 7;

    Omega_0 = almanac(almdataidx).GeographicLongitudeOfOrbitalPlane;
    Omega_0Bin = num2bits(Omega_0, 24, 2^-23);

    word7 = gpsLNavWordEnc(Omega_0Bin, wordNum);

    wordNum = 8;

    omega = almanac(almdataidx).ArgumentOfPerigee;
    omegaBin = num2bits(omega, 24, 2^-23);

    word8 = gpsLNavWordEnc(omegaBin, wordNum);

    wordNum = 9;

    M0 = almanac(almdataidx).MeanAnomaly;
    M0Bin = num2bits(M0, 24, 2^-23);

    word9 = gpsLNavWordEnc(M0Bin, wordNum);

    wordNum = 10;

    af0 = almanac(almdataidx).ZerothOrderClockCorrection;
    af0Bin = num2bits(af0, 11, 2^-20);

    af1 = almanac(almdataidx).FirstOrderClockCorrection;
    af1Bin = num2bits(af1, 11, 2^-38);

    data = [af0Bin(1:8); af1Bin; af0Bin(9:11)];
    word10 = gpsLNavWordEnc(data, wordNum);
end

bits = [word3; word4; word5; word6; word7; word8; word9; word10];
end

function word = TLMWord(tlmdata)
%TLMWORD generates the telemetry (TLM) word
%   WORD = TLMWord(TLMDATA) generates the 30 bit length telemetry word,
%   WORD as per the data contained in TLMDATA. When TLMDATA.DefaultTLMFlag
%   is set, irrespective of anything in TLMWORD, default value of TLM word
%   will be generated. Leaving the 6 bits parity, default TLM word is
%   [1;0;0;0;1;0;1;1; zeros(16,1)]. TLMDATA is a structure or configuration
%   object with following parameters
%
%   TLMPreamble         - an integer which is of 8 bit length
%   TLMMessage          - an integer which is of 14 bits length
%   IntegrityStatusFlag - Binary value

preamble = num2bits(tlmdata.Preamble, 8, 1);
TLMMessage = num2bits(tlmdata.TLMMessage, 14, 1);
flags = [tlmdata.IntegrityStatusFlag; 0];
data = [preamble; TLMMessage; flags];
wordNumber = 1;
word = gpsLNavWordEnc(data,wordNumber);
end

function nmctBin = NMCT2Bin(erd)
%Converts the ERD values to binary values
%   NMCTBIN = NMCT2Bin(ERD) converts the ERD values to binary values and
%   returns a binary matrix NMCTBIN. ERD is a column vector of length 30
%   containing NMCT ERD values in each element of the array. NMCTBIN in a
%   binary matrix with number of rows same as that of ERD and number of
%   columns equal to 6.

numeleInNMCT = length(erd);

numBits = 6;
scaleFactor = 0.3;
nmctBin = zeros(numeleInNMCT, numBits);

for iERD = 1:numeleInNMCT
    nmctBin(iERD, :) = num2bits(erd(iERD), numBits, scaleFactor);
end
end

function codeWord = gpsLNavWordEnc(data,wordNumber)
%Encode the GPS LNAV word
%   CODEWORD = gpsLNavWordEnc(DATA,WORDNUMBER) encodes DATA using the
%   encoding scheme specified in IS-GPS-200K to obtain the encoded
%   CODEWORD. DATA is a vector of bits. If WORDNUMBER is either 2 or 10,
%   then DATA should be a vector of 22 bits and for other value of
%   WORDNUMBER, DATA is a vector of 24 bits. CODEWORD is a vector of 30
%   bits.

persistent d29Star d30Star
if wordNumber==1 || isempty(d29Star)
    d29Star=0;
    d30Star=0;
end
% Parity Polynomials for bits 25 to 30
d25 = [1 2 3 5 6 10 11 12 13 14 17 18 20 23];
d26 = [2 3 4 6 7 11 12 13 14 15 18 19 21 24];
d27 = [1 3 4 5 7 8 12 13 14 15 16 19 20 22];
d28 = [2 4 5 6 8 9 13 14 15 16 17 20 21 23];
d29 = [1 3 5 6 7 9 10 14 15 16 17 18 21 22 24];
d30 = [3 5 6 8 9 10 11 13 15 19 22 23 24];

data = data(:); % As data should always be a column vector

if wordNumber~=2 && wordNumber~=10
    %Vectorize parity application to data
    dataParity = d30Star*ones(24, 1);

    %Generate Codeword based on the parity equations from the ICD -
    %Hamming(32,26)
    codeWord = mod([dataParity+data; d29Star+sum(data(d25));...
        d30Star+sum(data(d26)); d29Star+sum(data(d27));...
        d30Star+sum(data(d28)); d30Star+sum(data(d29));...
        d29Star+sum(data(d30))],2);

    %Update the D30* and D29* Value for the next word of subframe
    d30Star = codeWord(30);
    d29Star = codeWord(29);

end

%Parity for the Handover word and word number 10 is generated differently
% Word number 2 and 10 have bits 29 and 30 set to 0 and the parity is then
% generated accordingly. The values of bits 23 and 24 are then calculated
% to satisfy this condition.
if wordNumber==2 || wordNumber==10
    %Vectorize Parity application to data
    dataParity = d30Star*ones(22, 1);

    %Bits 23 and 24 have to be calculated by setting D29 and D30 to zero
    bit24 = mod(sum(data(d29(d29<23)))+...
        d30Star,2);
    bit23 = mod(sum(data(d30(d30<23)))+bit24+...
        d29Star,2);

    %Generate Parity Encoded Data
    codeWord = mod([dataParity+data(1:22); d30Star+bit23;...
        d30Star+bit24; d29Star+sum(data(d25(d25<23)))+bit23;...
        d30Star+sum(data(d26(d26<23)))+bit24; d29Star+sum(data(d27(d27<23)));...
        d30Star+sum(data(d28(d28<23)))+bit23; 0; 0],2);

    %Update the D30* and D29* Value for the next word of subframe
    d29Star=0;
    d30Star=0;

end
end

function CNAVBits = GPSCNAVDataEncode(cfg)
%GPSCNAVDataEncode Navigation data bits generation for L2C CNAV GPS
%
%   CNAVBITS = GPSCNAVDataEncode(CFG) generates the encoded bit
%   stream CNAVBITS which contains data bits for L2C GPS transmission.
%   CFG is a configuration object of type <a href="matlab:help('HelperGPSNavigationConfig')">HelperGPSNavigationConfig</a>. The
%   data bits are generated from the fields that go into modernized GPS
%   data. Each of these fields are available in the configuration object,
%   CFG. The properties and the encoding procedure is given in
%   Appendix III of IS-GPS-200 [1].

% Read the almanac file
[~, almWeekNum, almTimeOfApplicability, almStruct] = ...
    matlabshared.internal.gnss.readSEMAlmanac(cfg.AlmanacFileName);
if ~isfield(almStruct,'L1Health') % Assign L1,L2 and L5 health flags if they are not available from the output of almanac reader
    [almStruct(:).L1Health] = deal(0);
end
if ~isfield(almStruct,'L2Health')
    [almStruct(:).L2Health] = deal(0);
end
if ~isfield(almStruct,'L5Health')
    [almStruct(:).L5Health] = deal(0);
end

sequence = cfg.MessageTypes(:);
% Each message type contains 300 bits
numSequence = length(sequence);
CNAVBits = zeros(300*numSequence, 1, 'int8');

% Clearing persistent variables
getReducedAlmanacPacket();
getCDCPacket();
getEDCPacket();
almidx = 1;

TOW = cfg.HOWTOW;
for idx = 1:numSequence
    % For every 6 seconds, 17 MSBs of TOW gets incremented by 1. As each
    % message is 12 seconds long, TOW must be incremented by 2.
    cfg.HOWTOW = TOW + (idx-1)*2;
    startIdx = 300*(idx - 1) + 1;
    endIdx = 300*(idx - 1) + 300;
    switch sequence(idx)
        case 10
            CNAVBits(startIdx:endIdx) = messageType10(cfg);
        case 11
            CNAVBits(startIdx:endIdx) = messageType11(cfg);
        case 30
            CNAVBits(startIdx:endIdx) = messageType30(cfg);
        case 31
            CNAVBits(startIdx:endIdx) = messageType31(cfg,almStruct,almTimeOfApplicability,almWeekNum);
        case 32
            CNAVBits(startIdx:endIdx) = messageType32(cfg);
        case 33
            CNAVBits(startIdx:endIdx) = messageType33(cfg);
        case 34
            CNAVBits(startIdx:endIdx) = messageType34(cfg);
        case 35
            CNAVBits(startIdx:endIdx) = messageType35(cfg);
        case 36
            CNAVBits(startIdx:endIdx) = messageType36(cfg);
        case 37
            CNAVBits(startIdx:endIdx) = messageType37(cfg,almStruct,almTimeOfApplicability,almWeekNum,almidx);
            almidx = almidx + 1;
        case 12
            CNAVBits(startIdx:endIdx) = messageType12(cfg,almStruct,almTimeOfApplicability,almWeekNum);
        case 13
            CNAVBits(startIdx:endIdx) = messageType13(cfg);
        case 14
            CNAVBits(startIdx:endIdx) = messageType14(cfg);
        case 15
            CNAVBits(startIdx:endIdx) = messageType15(cfg);
        otherwise
            CNAVBits(startIdx:endIdx) = messageType0(cfg);
    end
end
end

function bits = messageType0(opts)
% Generates bits for message type 0

bits = getCommonParamBits(opts, 0);
x = [ones(1,119);zeros(1,119)];
bits = [bits;x(:)];
bits = CRCGen(bits);
end

function bits = messageType10(opts)
% Generates bits for message type 10

bits = getCommonParamBits(opts, 10);
bits = [bits;num2bits(opts.WeekNumber, 13, 1)];
bits = [bits;opts.SignalHealth(1)];
bits = [bits;opts.SignalHealth(2)];
bits = [bits;opts.SignalHealth(3)];
bits = [bits;num2bits(opts.ReferenceTimeCEIPropagation, 11, 300)];
bits = [bits;num2bits(opts.URAEDID, 5, 1)];
bits = [bits;num2bits(opts.ReferenceTimeOfEphemeris, 11, 300)];
bits = [bits;num2bits(opts.SemiMajorAxisLength-26559710, 26, 2^-9)]; % What is transmitted is semi-major axis length difference with respect to ARef = 26559710
bits = [bits;num2bits(opts.ChangeRateInSemiMajorAxis, 25, 2^-21)];
bits = [bits;num2bits(opts.MeanMotionDifference, 17, 2^-44)];
bits = [bits;num2bits(opts.RateOfMeanMotionDifference, 23, 2^-57)];
bits = [bits;num2bits(opts.MeanAnomaly, 33, 2^-32)];
bits = [bits;num2bits(opts.Eccentricity, 33, 2^-34)];
bits = [bits;num2bits(opts.ArgumentOfPerigee, 33, 2^-32)];
bits = [bits;opts.IntegrityStatusFlag];
bits = [bits;opts.L2CPhasing];
bits = [bits;zeros(3,1)];
bits = CRCGen(bits);
end

function bits = messageType11(opts)
% Generates bits for message type 11

bits = getCommonParamBits(opts, 11);
bits = [bits;num2bits(opts.ReferenceTimeOfEphemeris, 11, 300)];
bits = [bits;num2bits(opts.LongitudeOfAscendingNode, 33, 2^-32)];
bits = [bits;num2bits(opts.Inclination, 33, 2^-32)];
bits = [bits;num2bits(opts.RateOfRightAscension+2.6e-9, 17, 2^-44)];
bits = [bits;num2bits(opts.InclinationRate, 15, 2^-44)];
bits = [bits;num2bits(opts.HarmonicCorrectionTerms(1), 16, 2^-30)];
bits = [bits;num2bits(opts.HarmonicCorrectionTerms(2), 16, 2^-30)];
bits = [bits;num2bits(opts.HarmonicCorrectionTerms(3), 24, 2^-8)];
bits = [bits;num2bits(opts.HarmonicCorrectionTerms(4), 24, 2^-8)];
bits = [bits;num2bits(opts.HarmonicCorrectionTerms(5), 21, 2^-30)];
bits = [bits;num2bits(opts.HarmonicCorrectionTerms(6), 21, 2^-30)];
bits = [bits;zeros(7,1)];
bits = CRCGen(bits);
end

function bits = messageType30(opts)
% Generates bits for message type 30

bits = getCommonParamBits(opts, 30);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(opts.GroupDelayDifferential, 13, 2^-35)];
bits = [bits;num2bits(opts.InterSignalCorrection(1), 13, 2^-35)];
bits = [bits;num2bits(opts.InterSignalCorrection(2), 13, 2^-35)];
bits = [bits;num2bits(opts.InterSignalCorrection(3), 13, 2^-35)];
bits = [bits;num2bits(opts.InterSignalCorrection(4), 13, 2^-35)];
bits = [bits;num2bits(opts.Ionosphere.Alpha(1), 8, 2^-30)];
bits = [bits;num2bits(opts.Ionosphere.Alpha(2), 8, 2^-27)];
bits = [bits;num2bits(opts.Ionosphere.Alpha(3), 8, 2^-24)];
bits = [bits;num2bits(opts.Ionosphere.Alpha(4), 8, 2^-24)];
bits = [bits;num2bits(opts.Ionosphere.Beta(1), 8, 2^11)];
bits = [bits;num2bits(opts.Ionosphere.Beta(2), 8, 2^14)];
bits = [bits;num2bits(opts.Ionosphere.Beta(3), 8, 2^16)];
bits = [bits;num2bits(opts.Ionosphere.Beta(4), 8, 2^16)];
bits = [bits;num2bits(opts.ReferenceWeekNumberCEIPropagation, 8, 1)];
bits = [bits;zeros(12,1)];
bits = CRCGen(bits);
end

function bits = messageType31(opts,almanac,almTimeOfApplicability,almwn)
% Generates bits for message type 31

bits = getCommonParamBits(opts, 31);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(mod(almwn, 2^14), 13, 1)];
bits = [bits;num2bits(almTimeOfApplicability, 8, 2^12)];
prevDummySat = 0;
reducedAlmanacPackets = zeros(124, 1);
for idx = 1:4
    startIdx = (idx-1) * 31 + 1;
    endIdx = (idx - 1) * 31 + 31;
    [reducedAlmanacBits, dummySat] = getReducedAlmanacPacket(almanac, prevDummySat);
    reducedAlmanacPackets(startIdx:endIdx) = reducedAlmanacBits;
    prevDummySat = dummySat;
end
bits = [bits;reducedAlmanacPackets];
bits = [bits;zeros(4,1)];
bits = CRCGen(bits);
end

function bits = messageType32(opts)
% Generates bits for message type 32

bits = getCommonParamBits(opts, 32);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(opts.EarthOrientation.ReferenceTimeEOP, 16, 2^4)];
bits = [bits;num2bits(opts.EarthOrientation.XAxisPolarMotionValue, 21, 2^-20)];
bits = [bits;num2bits(opts.EarthOrientation.XAxisPolarMotionDrift, 15, 2^-21)];
bits = [bits;num2bits(opts.EarthOrientation.YAxisPolarMotionValue, 21, 2^-20)];
bits = [bits;num2bits(opts.EarthOrientation.YAxisPolarMotionDrift, 15, 2^-21)];
bits = [bits;num2bits(opts.EarthOrientation.UT1_UTCDifference, 31, 2^-23)];
bits = [bits;num2bits(opts.EarthOrientation.RateOfUT1_UTCDifference, 19, 2^-25)];
bits = [bits;zeros(11,1)];
bits = CRCGen(bits);
end


function bits = messageType33(opts)
% Generates bits for message type 33

bits = getCommonParamBits(opts, 33);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(opts.UTC.UTCTimeCoefficients(1), 16, 2^-35)];
bits = [bits;num2bits(opts.UTC.UTCTimeCoefficients(2), 13, 2^-51)];
bits = [bits;num2bits(opts.UTC.UTCTimeCoefficients(3), 7, 2^-68)];
bits = [bits;num2bits(opts.UTC.PastLeapSecondCount, 8, 1)];
bits = [bits;num2bits(opts.UTC.ReferenceTimeUTCData, 16, 2^4)];
bits = [bits;num2bits(opts.UTC.TimeDataReferenceWeekNumber, 13, 1)];
bits = [bits;num2bits(opts.UTC.LeapSecondReferenceWeekNumber, 13, 1)];
bits = [bits;num2bits(opts.UTC.LeapSecondReferenceDayNumber, 4, 1)];
bits = [bits;num2bits(opts.UTC.FutureLeapSecondCount, 8, 1)];
bits = [bits;zeros(51,1)];
bits = CRCGen(bits);
end

function bits = messageType34(opts)
% Generates bits for message type 34

DCParams = opts.DifferentialCorrection;
bits = getCommonParamBits(opts, 34);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(DCParams.ReferenceTimeDCDataPredict, 11, 300)];
bits = [bits;num2bits(DCParams.ReferenceTimeDCData, 11, 300)];
bits = [bits;getCDCPacket(DCParams)];
EDCPacket = getEDCPacket(DCParams);
bits = [bits;EDCPacket(2:end)];
bits = CRCGen(bits);
end

function bits = messageType35(opts)
% Generates bits for message type 35

bits = getCommonParamBits(opts, 35);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(opts.TimeOffset.ReferenceTimeGGTO, 16, 2^4)];
bits = [bits;num2bits(opts.TimeOffset.WeekNumberGGTO, 13, 2^0)];
bits = [bits;num2bits(opts.TimeOffset.GNSSID, 3, 1)];
bits = [bits;num2bits(opts.TimeOffset.GGTOCoefficients(1), 16, 2^-35)];
bits = [bits;num2bits(opts.TimeOffset.GGTOCoefficients(2), 13, 2^-51)];
bits = [bits;num2bits(opts.TimeOffset.GGTOCoefficients(3), 7, 2^-68)];
bits = [bits;zeros(81,1)];
bits = CRCGen(bits);
end

function bits = messageType36(opts)
% Generates bits for message type 36

bits = getCommonParamBits(opts, 36);
bits = [bits;getClockParams(opts)];
numCharInMessage = 18;
fullText = char(opts.TextInMessageType36(:).');
if length(fullText) >= numCharInMessage
    text = fullText(1:numCharInMessage);
else
    text = [fullText, repmat(' ',1, numCharInMessage-length(fullText))];
end
bits = [bits;int2bit(double(text(:)),8)];

% Text message and text page are two separate fields. IS-GPS-200k does not
% explain what this text page field specifies. Filled it as zeros of length
% 4 where 4 is the length of the field.
bits = [bits;zeros(4,1)];
bits = [bits;zeros(1,1)];
bits = CRCGen(bits);
end

function bits = messageType37(opts,almanac,almTimeOfApplicability,almWeekNum,almidx)
% Generates bits for message type 37

bits = getCommonParamBits(opts, 37);
bits = [bits;getClockParams(opts)];
bits = [bits;num2bits(mod(almWeekNum, 2^14), 13, 1)];
bits = [bits;num2bits(almTimeOfApplicability, 8, 2^12)];
bits = [bits;getMidiAlmanacParams(almanac,almidx)];
bits = CRCGen(bits);
end

function bits = messageType12(opts,almanac,almTimeOfApplicability,almWeekNum)
% Generates bits for message type 12

bits = getCommonParamBits(opts, 12);
bits = [bits;num2bits(mod(almWeekNum, 2^14), 13, 1)];
bits = [bits;num2bits(almTimeOfApplicability, 8, 2^12)];
prevDummySat = 0;
reducedAlmanacPackets = zeros(217, 1);
for idx = 1:7
    startIdx = (idx-1) * 31 + 1;
    endIdx = (idx - 1) * 31 + 31;
    [reducedAlmanacBits, dummySat] = getReducedAlmanacPacket(almanac, prevDummySat);
    reducedAlmanacPackets(startIdx:endIdx) = reducedAlmanacBits;
    prevDummySat = dummySat;
end
bits = [bits;reducedAlmanacPackets];
bits = CRCGen(bits);

end

function bits = messageType13(opts)
% Generates bits for message type 13

DCParams = opts.DifferentialCorrection;
bits = getCommonParamBits(opts, 13);
bits = [bits;num2bits(DCParams.ReferenceTimeDCDataPredict, 11, 300)];
bits = [bits;num2bits(DCParams.ReferenceTimeDCData, 11, 300)];
bits = [bits;getCDCPacket(DCParams)];
bits = [bits;getCDCPacket(DCParams)];
bits = [bits;getCDCPacket(DCParams)];
bits = [bits;getCDCPacket(DCParams)];
bits = [bits;getCDCPacket(DCParams)];
bits = [bits;getCDCPacket(DCParams)];
bits = [bits;zeros(6,1)];
bits = CRCGen(bits);
end

function bits = messageType14(opts)
% Generates bits for message type 14

DCParams = opts.DifferentialCorrection;
bits = getCommonParamBits(opts, 14);
bits = [bits;num2bits(DCParams.ReferenceTimeDCDataPredict, 11, 300)];
bits = [bits;num2bits(DCParams.ReferenceTimeDCData, 11, 300)];
bits = [bits;getEDCPacket(DCParams)];
bits = [bits;getEDCPacket(DCParams)];
bits = [bits;zeros(30,1)];
bits = CRCGen(bits);
end

function bits = messageType15(opts)
% Generates bits for message type 15

numCharInMessage = 29;
bits = getCommonParamBits(opts, 15);
fullText = char(opts.TextInMessageType15(:).');
if length(fullText) >= numCharInMessage
    text = fullText(1:numCharInMessage);
else
    text = [fullText, repmat(' ',1, numCharInMessage-length(fullText))];
end
bits = [bits;int2bit(double(text(:)),8)];

% Text message and text page are two separate fields. IS-GPS-200k does not
% explain what this text page field specifies. Filled it as zeros of length
% 4 where 4 is the length of the field.
bits = [bits;zeros(4,1)];
bits = [bits;zeros(2,1)];
bits = CRCGen(bits);
end

function bits = getCommonParamBits(opts, messageTypeId)
% Generates bits corresponding to preamble, PRNIdx, message type ID, TOW
% and alert flag which are present in all message types

bits = num2bits(opts.Preamble, 8, 1);
bits = [bits;num2bits(opts.PRNID, 6, 1)];
bits = [bits;num2bits(messageTypeId, 6, 1)];
bits = [bits;num2bits(opts.HOWTOW, 17, 1)];
bits = [bits;opts.AlertFlag];
end

function bits = getClockParams(opts)
% Generates clock correction and accuracy parameters bits for message types
% 30 to 37.

bits = num2bits(opts.ReferenceTimeCEIPropagation, 11, 300);
bits = [bits;num2bits(opts.URANEDID(1), 5, 1)];
bits = [bits;num2bits(opts.URANEDID(2), 3, 1)];
bits = [bits;num2bits(opts.URANEDID(3), 3, 1)];
bits = [bits;num2bits(opts.ReferenceTimeOfClock, 11, 300)];
bits = [bits;num2bits(opts.SVClockCorrectionCoefficients(1), 26, 2^-35)];
bits = [bits;num2bits(opts.SVClockCorrectionCoefficients(2), 20, 2^-48)];
bits = [bits;num2bits(opts.SVClockCorrectionCoefficients(3), 10, 2^-60)];
end

function bits = CRCGen(inputBits)
% Returns 300-bit message after appending 24 CRC bits at the end of message

persistent crcgenerator
if isempty(crcgenerator)
    crcgenerator = comm.CRCGenerator('Polynomial', ...
        'z^24 + z^23 + z^18 + z^17 + z^14 + z^11 + z^10 + z^7 + z^6 + z^5 + z^4 + z^3 + z + 1');
end
bits = crcgenerator(inputBits);
end

function [bits, dummySat] = getReducedAlmanacPacket(Almanac, prevDummySat)
%GETREDUCEDALMANACPACKET generated bits in reduced almanac packet for
%   message types 31 and 12.
%   [BITS, DUMMYSAT] = getReducedAlmanac(ALMANAC, PREVDUMMYSAT) generates
%   31 bits reduced almanac packet for an SV.
%
%   BITS            - Reduced almanac packet
%   DUMMYSAT        - Flag indicating current packet contains
%                     dummy satellite data
%   ALMANAC         - Structure containing almanac parameters
%   PREVDUMMYSAT    - Flag indicating dummy satellite data in any of the
%                     previous reduced almanac packets in the message

% Index to transmit reduced almanac data in ascending order of PRN numbers
% of satellites in constellation
persistent redAlmanacIdx nextPRN lastDummyBit

if nargin == 0
    clear redAlmanacIdx nextPRN lastDummyBit
else
    if isempty(redAlmanacIdx) || redAlmanacIdx >= 31
        redAlmanacIdx = 0;
        nextPRN = 1;
    end
    if isempty(lastDummyBit)
        lastDummyBit = 1;
    end

    redAlmanacIdx = redAlmanacIdx + 1;
    PRN_a = Almanac(redAlmanacIdx).PRNNumber;

    if prevDummySat == 1
        % If there is a previous dummy satellite in the message, bits after PRN
        % field of the reduced almanac packet of dummy satellite through the last
        % bit of last almanac packet will be filler bits.
        x = [xor(ones(1,15),lastDummyBit);repmat(lastDummyBit,1,15)];
        bits = [x(:);xor(1,lastDummyBit)];
        lastDummyBit = xor(1,lastDummyBit);
        dummySat = 1;
        redAlmanacIdx = redAlmanacIdx - 1;

    elseif PRN_a == nextPRN && prevDummySat == 0
        bits = num2bits(PRN_a, 6, 1);
        del_A = (Almanac(redAlmanacIdx).SqrtOfSemiMajorAxis^2) - 26559710; % del_A is with respect to 26559710 meters
        bits = [bits;num2bits(del_A, 8, 2^9)];
        omega_0 = Almanac(redAlmanacIdx).GeographicLongitudeOfOrbitalPlane;
        bits = [bits;num2bits(omega_0, 7, 2^-6)];
        phi_0 = Almanac(redAlmanacIdx).MeanAnomaly + Almanac(redAlmanacIdx).ArgumentOfPerigee;
        bits = [bits;num2bits(phi_0, 7, 2^-6)];
        bits = [bits;Almanac(redAlmanacIdx).L1Health];
        bits = [bits;Almanac(redAlmanacIdx).L2Health];
        bits = [bits;Almanac(redAlmanacIdx).L5Health];
        dummySat = 0;
        nextPRN = nextPRN + 1;

    elseif PRN_a ~= nextPRN && prevDummySat == 0
        % If current satellite is a dummy satellite, PRN field will be "000000"
        % and all subsequent bits through the last bit of the last packet in
        % the message will be filler bits.
        bits = zeros(6, 1);
        x = [ones(1,12);zeros(1,12)];
        bits = [bits;x(:);1];
        dummySat = 1;
        lastDummyBit = 1;
        nextPRN = nextPRN + 1;
        redAlmanacIdx = redAlmanacIdx - 1;
    end
end
end

function bits = getMidiAlmanacParams(Almanac,midiAlmanacIdx)
% Generates midi almanac parameters bits for message type 37 in CNAV

PRN_a = Almanac(midiAlmanacIdx).PRNNumber;
bits = num2bits(PRN_a,6,1);
bits = [bits;Almanac(midiAlmanacIdx).L1Health];
bits = [bits;Almanac(midiAlmanacIdx).L2Health];
bits = [bits;Almanac(midiAlmanacIdx).L5Health];
e = Almanac(midiAlmanacIdx).Eccentricity;
bits = [bits;num2bits(e,11,2^-16)];
delta_i = Almanac(midiAlmanacIdx).InclinationOffset;
bits = [bits;num2bits(delta_i,11,2^-14)];
omegaDot = Almanac(midiAlmanacIdx).RateOfRightAscension;
bits = [bits;num2bits(omegaDot,11,2^-33)];
sqrtA = Almanac(midiAlmanacIdx).SqrtOfSemiMajorAxis;
bits = [bits;num2bits(sqrtA,17,2^-4)];
omega_0 = Almanac(midiAlmanacIdx).GeographicLongitudeOfOrbitalPlane;
bits = [bits;num2bits(omega_0,16,2^-15)];
omega = Almanac(midiAlmanacIdx).ArgumentOfPerigee;
bits = [bits;num2bits(omega,16,2^-15)];
M_0 = Almanac(midiAlmanacIdx).MeanAnomaly;
bits = [bits;num2bits(M_0,16,2^-15)];
a_f0 = Almanac(midiAlmanacIdx).ZerothOrderClockCorrection;
bits = [bits;num2bits(a_f0,11,2^-20)];
a_f1 = Almanac(midiAlmanacIdx).FirstOrderClockCorrection;
bits = [bits;num2bits(a_f1,10,2^-37)];
end

function bits = getCDCPacket(DCParams)
% Generate clock differential correction(CDC) packet for an SV

% Index to transmit CDC data in ascending order of PRN numbers of
% satellites in constellation
persistent CDCIdx

if nargin == 0
    clear CDCIdx
else
    if isempty(CDCIdx) || CDCIdx >= 31
        CDCIdx = 0;
    end

    CDCIdx = CDCIdx + 1;
    PRNIdx = DCParams.Data(CDCIdx).CDCPRNID;
    if ~isempty(PRNIdx)
        bits = DCParams.Data(CDCIdx).DCDataType;
        bits = [bits;num2bits(PRNIdx, 8, 1)];
        delta_a_f0 = DCParams.Data(CDCIdx).SVClockBiasCoefficient;
        bits = [bits;num2bits(delta_a_f0, 13, 2^-35)];
        delta_a_f1 = DCParams.Data(CDCIdx).SVClockDriftCorrection;
        bits = [bits;num2bits(delta_a_f1, 8, 2^-51)];
        UDRA = DCParams.Data(CDCIdx).UDRAID;
        bits = [bits;num2bits(UDRA, 5, 1)];

    else
        % In case of dummy satellite, PRN field is filled with all 1s and the
        % subsequent bits till the end of packet are filler bits.
        bits = [0;ones(8, 1)];
        x = [ones(1,13);zeros(1,13)];
        bits = [bits;x(:)];
    end
end
end

function bits = getEDCPacket(DCParams)
% Generates Ephemeris differential correction(EDC) packet for an SV

% Index to transmit EDC data in ascending order of PRN numbers of
% satellites in constellation
persistent EDCIdx
if nargin == 0
    clear EDCIdx
else
    if isempty(EDCIdx) || EDCIdx >= 31
        EDCIdx = 0;
    end

    EDCIdx = EDCIdx + 1;
    PRNIdx = DCParams.Data(EDCIdx).EDCPRNID;
    if ~isempty(PRNIdx)
        bits = DCParams.Data(EDCIdx).DCDataType;
        bits = [bits;num2bits(PRNIdx, 8, 1)];
        alphaCorrection = DCParams.Data(EDCIdx).AlphaCorrection;
        bits = [bits;num2bits(alphaCorrection, 14, 2^-34)];
        betaCorrection = DCParams.Data(EDCIdx).BetaCorrection;
        bits = [bits;num2bits(betaCorrection, 14, 2^-34)];
        gammaCorrection = DCParams.Data(EDCIdx).GammaCorrection;
        bits = [bits;num2bits(gammaCorrection, 15, 2^-32)];
        delta_i = DCParams.Data(EDCIdx).InclinationCorrection;
        bits = [bits;num2bits(delta_i, 12, 2^-32)];
        delta_omega = DCParams.Data(EDCIdx).RightAscensionCorrection;
        bits = [bits;num2bits(delta_omega, 12, 2^-32)];
        delta_A = DCParams.Data(EDCIdx).SemiMajorAxisCorrection;
        bits = [bits;num2bits(delta_A, 12, 2^-9)];
        UDRADot = DCParams.Data(EDCIdx).UDRARateID;
        bits = [bits;num2bits(UDRADot, 5, 1)];

    else
        % In case of dummy satellite, PRN field is filled with all 1s and the
        % subsequent bits till the end of packet are filler bits.
        bits = [0;ones(8, 1)];
        x = [ones(1,42);zeros(1,42)];
        bits = [bits;x(:)];
    end
end
end

function d = GPSCNAV2DataEncode(cfg)
%GPSCNAV2DataEncode Navigation data bits generation for CNAV2 GPS (L1C)
%   D = GPSCNAV2DataEncode(CFG) forms GPS L1C frames as defined in
%   IS-GPS-800 [2] standard from the configuration, CFG. D is the data bits
%   after converting the civil navigation second (CNAV2) configuration,
%   CFG to the frames.

% Read the almanac file
[~, almWeekNum, almTimeOfApplicability, almStruct] = ...
    matlabshared.internal.gnss.readSEMAlmanac(cfg.AlmanacFileName);
if ~isfield(almStruct,'L1Health') % Assign L1,L2 and L5 health flags if they are not available from the output of almanac reader
    [almStruct(:).L1Health] = deal(0);
end
if ~isfield(almStruct,'L2Health')
    [almStruct(:).L2Health] = deal(0);
end
if ~isfield(almStruct,'L5Health')
    [almStruct(:).L5Health] = deal(0);
end

toi = mod(cfg.L1CTOI,400); 

% Load A1, B1, C1, E1, T1 matrices from file to use in LDPC encoder of subframe2. These tables are taken
% from Table 6.2-2 to 6.2-7 in IS-GPS-800.
load("L1CLDPCParityCheckMatrices.mat","A1","B1","C1","E1","T1");
% Convert these tables into matrices to use in the LDPC encoder
l1cLDPCA1 = logical(sparse(A1(:,1),A1(:,2),1,599,600));
l1cLDPCB1 = logical(sparse(B1(:,1),B1(:,2),1,599,1));
l1cLDPCC1 = logical(sparse(C1(:,1),C1(:,2),1,1,600));
l1cLDPCD1 = true;
l1cLDPCE1 = logical(sparse(E1(:,1),E1(:,2),1,1,599));
l1cLDPCT1 = logical(sparse(T1(:,1),T1(:,2),1,599,599));
cfgLDPCSubframe2 = ldpcEncoderConfig([l1cLDPCA1, l1cLDPCB1, l1cLDPCT1; l1cLDPCC1, l1cLDPCD1, l1cLDPCE1]);
crcGeneratorSubframe2 = comm.CRCGenerator('Polynomial', ...
    'z^24 + z^23 + z^18 + z^17 + z^14 + z^11 + z^10 + z^7 + z^6 + z^5 + z^4 + z^3 + z + 1');
s3PageSeq = cfg.L1CSubframe3PageSequence;

numPages = length(s3PageSeq(:));
% Initialize S1 and S3 bits to zeros
s3Bits = zeros(548,numPages); % Subframe 3 after LDPC encoding has 548 bits
dTemp = zeros(1800,numPages); % Each frame has 1800 bits after all the encoding is complete

almCount = 1;
dcParamCount = 1;
dcParamStruct = cfg.DifferentialCorrection.Data;
textPageCount = 0;
fullText = cfg.TextMessage;
fullTextLength = length(fullText(:));
svconfig = [almStruct(:).SatelliteConfiguration];
svconfig = [svconfig;[almStruct(:).PRNNumber]];

% Load A2, B2, C2, E2, T2 matrices from file for LDPC encoding of
% subframe3. These tables are taken from Table 6.2-8 to 6.2-13 in
% IS-GPS-800.
load("L1CLDPCParityCheckMatrices.mat","A2","B2","C2","E2","T2");

% Convert these tables into matrices to use in the LDPC encoder
l1cLDPCA2 = logical(sparse(A2(:,1),A2(:,2),1,273,274));
l1cLDPCB2 = logical(sparse(B2(:,1),B2(:,2),1,273,1));
l1cLDPCC2 = logical(sparse(C2(:,1),C2(:,2),1,1,274));
l1cLDPCD2 = true;
l1cLDPCE2 = logical(sparse(E2(:,1),E2(:,2),1,1,273));
l1cLDPCT2 = logical(sparse(T2(:,1),T2(:,2),1,273,273));
cfgLDPCSubframe3 = ldpcEncoderConfig([l1cLDPCA2, l1cLDPCB2, l1cLDPCT2; l1cLDPCC2, l1cLDPCD2, l1cLDPCE2]);

crcGeneratorSubframe3 = comm.CRCGenerator('Polynomial', ...
    'z^24 + z^23 + z^18 + z^17 + z^14 + z^11 + z^10 + z^7 + z^6 + z^5 + z^4 + z^3 + z + 1');
numcharPerPage = 29;
if fullTextLength<numcharPerPage
    textIndices = 1:fullTextLength;
else
    textIndices = 1:numcharPerPage; % Take the first 29 characters from the full text message
end
for iPage = 1:numPages
    numBlanksInTextMessage = numcharPerPage - length(textIndices);
    textMessage = [fullText(textIndices), repmat(' ', 1, numBlanksInTextMessage)];
    toiBits = num2bits(toi,9,1);
    s1Bits = gpsTOIEnc(toiBits);
    s2Bits = l1cSubframe2(cfg,cfgLDPCSubframe2,crcGeneratorSubframe2);
    s3Bits(:,iPage) = l1cSubframe3(cfg,s3PageSeq(iPage),almStruct(almCount), ...
        almWeekNum,almTimeOfApplicability,dcParamStruct(dcParamCount), ...
        textMessage,textPageCount,svconfig,cfgLDPCSubframe3,crcGeneratorSubframe3);
    
    % Udpate the counters
    toi = mod(toi + 1, 400);
    if toi == 0 % Last frame in 2 hour period generation is complete. So, update ITOW
        cfg.L1CITOW = mod(cfg.L1CITOW + 1, 84);
    end

    if s3PageSeq(iPage) == 4 % Update the almanac counter
        almCount = mod(almCount,length(almStruct))+1;
    end

    if s3PageSeq(iPage) == 5
        dcParamCount = mod(dcParamCount,length(dcParamStruct)) + 1;
    end

    if s3PageSeq(iPage) == 6
        tempIndices = textIndices(end)+1:fullTextLength;
        if length(tempIndices) > numcharPerPage
            textIndices = tempIndices(1:numcharPerPage);
        else
            textIndices = tempIndices;
        end
        textPageCount = mod(textPageCount+1,16);
    end

    % Form the frame as per standard
    s2s3 = matintrlv([s2Bits;s3Bits(:,iPage)],38,46); % Subframe 2 and subframe 3 together form 1748 bits. For purpose of interleaving arrange those bits in 38 rows and 46 columns
    dTemp(:,iPage) = [s1Bits;s2s3];
end
d = dTemp(:); % Arrange the entire data into a single column vector
end

function s2Bits = l1cSubframe2(cfg,cfgLDPC,crcgenerator)

WN = num2bits(cfg.WeekNumber,13,1);
ITOW = num2bits(cfg.L1CITOW,8,1);
t_op = num2bits(cfg.ReferenceTimeCEIPropagation,11,300);
L1CHealth = cfg.L1CHealth;
URAEDID = num2bits(cfg.URAEDID,5,1);
t_oe = num2bits(cfg.ReferenceTimeOfEphemeris,11,300);
A = cfg.SemiMajorAxisLength;
DeltaA = num2bits(A - 26559710,26,2^-9);
A_Dot = num2bits(cfg.ChangeRateInSemiMajorAxis,25,2^-21);
Deltan0 = num2bits(cfg.MeanMotionDifference,17,2^-44);
Deltan0Dot = num2bits(cfg.RateOfMeanMotionDifference,23,2^-57);
M_0 = num2bits(cfg.MeanAnomaly,33,2^-32);
e = num2bits(cfg.Eccentricity,33,2^-34);
omega = num2bits(cfg.ArgumentOfPerigee,33,2^-32);
Omega = num2bits(cfg.LongitudeOfAscendingNode,33,2^-32);
DeltaOmegaDot = num2bits(cfg.RateOfRightAscension+2.6e-9,17,2^-44); % OmegaRef = -2.6e-9.
i0 = num2bits(cfg.Inclination,33,2^-32);
iDOT = num2bits(cfg.InclinationRate,15,2^-44);
Cis = num2bits(cfg.HarmonicCorrectionTerms(1),16,2^-30);
Cic = num2bits(cfg.HarmonicCorrectionTerms(2),16,2^-30);
Crs = num2bits(cfg.HarmonicCorrectionTerms(3),24,2^-8);
Crc = num2bits(cfg.HarmonicCorrectionTerms(4),24,2^-8);
Cus = num2bits(cfg.HarmonicCorrectionTerms(5),21,2^-30);
Cuc = num2bits(cfg.HarmonicCorrectionTerms(6),21,2^-30);
URANED0ID = num2bits(cfg.URANEDID(1),5,1);
URANED1ID = num2bits(cfg.URANEDID(2),3,1);
URANED2ID = num2bits(cfg.URANEDID(3),3,1);
af0 = num2bits(cfg.SVClockCorrectionCoefficients(1),26,2^-35);
af1 = num2bits(cfg.SVClockCorrectionCoefficients(2),20,2^-48);
af2 = num2bits(cfg.SVClockCorrectionCoefficients(3),10,2^-60);
T_GD = num2bits(cfg.GroupDelayDifferential,13,2^-35);
ISC_L1CP = num2bits(cfg.ISCL1CP,13,2^-35);
ISC_L1CD = num2bits(cfg.ISCL1CD,13,2^-35);
isc = cfg.IntegrityStatusFlag;
WN_op = num2bits(cfg.ReferenceWeekNumberCEIPropagation,8,1);

d = [WN;ITOW;t_op;L1CHealth;URAEDID;t_oe;DeltaA;A_Dot;Deltan0;Deltan0Dot; ...
    M_0;e;omega;Omega;i0;DeltaOmegaDot;iDOT;Cis;Cic;Crs;Crc;Cus;Cuc;URANED0ID; ...
    URANED1ID;URANED2ID;af0;af1;af2;T_GD;ISC_L1CP;ISC_L1CD;isc;WN_op;0;0]; % Data
bits = crcgenerator(d);
s2Bits = ldpcEncode(bits,cfgLDPC);
end

function s3Bits = l1cSubframe3(cfg,pageID,almStruct,almWeekNum, ...
    almTimeOfApplicability,dcParamStruct,textMessage,textPageCount,svconfig, ...
    cfgLDPC,crcgenerator)

% Parameters that are common to all the pages
prnid = num2bits(cfg.PRNID,8,1);
pageNum = num2bits(pageID,6,1);
switch(pageID)
    case 1
        % UTC Parameters
        A0 = num2bits(cfg.UTC.UTCTimeCoefficients(1),16,2^-35);
        A1 = num2bits(cfg.UTC.UTCTimeCoefficients(2),13,2^-53);
        A2 = num2bits(cfg.UTC.UTCTimeCoefficients(3),7,2^-68);
        Deltat_LS = num2bits(cfg.UTC.PastLeapSecondCount,8,1);
        t_ot = num2bits(cfg.UTC.ReferenceTimeUTCData,16,16);
        WN_ot = num2bits(cfg.UTC.TimeDataReferenceWeekNumber,13,1);
        WN_LSF = num2bits(cfg.UTC.LeapSecondReferenceWeekNumber,13,1);
        DN = num2bits(cfg.UTC.LeapSecondReferenceDayNumber,4,1);
        Deltat_LSF = num2bits(cfg.UTC.FutureLeapSecondCount,8,1);

        % Ionosphere parameters
        a0 = num2bits(cfg.Ionosphere.Alpha(1),8,2^-30);
        a1 = num2bits(cfg.Ionosphere.Alpha(2),8,2^-27);
        a2 = num2bits(cfg.Ionosphere.Alpha(3),8,2^-24);
        a3 = num2bits(cfg.Ionosphere.Alpha(4),8,2^-24);
        b0 = num2bits(cfg.Ionosphere.Beta(1),8,2^11);
        b1 = num2bits(cfg.Ionosphere.Beta(2),8,2^14);
        b2 = num2bits(cfg.Ionosphere.Beta(3),8,2^16);
        b3 = num2bits(cfg.Ionosphere.Beta(4),8,2^16);

        % Inter signal correction terms
        iscL1CA = num2bits(cfg.InterSignalCorrection(1),13,2^-35);
        iscL2C = num2bits(cfg.InterSignalCorrection(2),13,2^-35);
        iscL5I5 = num2bits(cfg.InterSignalCorrection(3),13,2^-35);
        iscL5Q5 = num2bits(cfg.InterSignalCorrection(4),13,2^-35);

        d = [A0;A1;A2;Deltat_LS;t_ot;WN_ot;WN_LSF;DN;Deltat_LSF; ...
            a0;a1;a2;a3;b0;b1;b2;b3;iscL1CA;iscL2C;iscL5I5;iscL5Q5;zeros(22,1)];
    case 2
        % GPS/GNSS Time offset parameters
        GNSSID = num2bits(cfg.TimeOffset.GNSSID,3,1);
        t_GGTO = num2bits(cfg.TimeOffset.ReferenceTimeGGTO,16,16);
        WN_GGTO = num2bits(cfg.TimeOffset.WeekNumberGGTO,13,1);
        A0GGTO = num2bits(cfg.TimeOffset.GGTOCoefficients(1),16,2^-35);
        A1GGTO = num2bits(cfg.TimeOffset.GGTOCoefficients(2),13,2^-51);
        A2GGTO = num2bits(cfg.TimeOffset.GGTOCoefficients(3),7,2^-68);

        % Earth orientation parameters
        t_EOP = num2bits(cfg.EarthOrientation.ReferenceTimeEOP,16,16);
        PM_X  = num2bits(cfg.EarthOrientation.XAxisPolarMotionValue,21,2^-20);
        PM_XRate  = num2bits(cfg.EarthOrientation.XAxisPolarMotionDrift,15,2^-21);
        PM_Y  = num2bits(cfg.EarthOrientation.YAxisPolarMotionValue,21,2^-20);
        PM_YRate  = num2bits(cfg.EarthOrientation.YAxisPolarMotionDrift,15,2^-21);
        DeltaUTGPS = num2bits(cfg.EarthOrientation.UT1_UTCDifference,31,2^-23);
        DeltaUTGPSRate = num2bits(cfg.EarthOrientation.RateOfUT1_UTCDifference,19,2^-25);

        d = [GNSSID;t_GGTO;WN_GGTO;A0GGTO;A1GGTO;A2GGTO;t_EOP;PM_X; ...
            PM_XRate;PM_Y;PM_YRate;DeltaUTGPS;DeltaUTGPSRate;zeros(30,1)];
    case 3
        % Reduced almanac
        WN_a = num2bits(cfg.ReducedAlmanac.WeekNumber,13,1);
        t_oa = num2bits(cfg.ReducedAlmanac.ReferenceTimeOfAlmanac,8,2^12);
        numReducedAlmanacPackets = 6; % There are 6 reduced almanac packets only
        almPackets = zeros(33,numReducedAlmanacPackets);
        for iAlm = 1:numReducedAlmanacPackets
            if cfg.ReducedAlmanac.Almanac(iAlm).PRNa == 0 % If PRNa is zero, then the entire page subsequent to this bit will be alternating ones and zeros
                numAlmPacketsToFill = numReducedAlmanacPackets-iAlm;
                numFillBits = numAlmPacketsToFill*33 + 25; % 25 bits extra because one dummy packet has first 8 bits as 00000000 because of PRN_a
                fillBits = [zeros(8,1);repmat([1;0],floor(numFillBits/2),1);zeros(mod(numFillBits,2),1)];
                almPackets(:,iAlm:end) = reshape(fillBits,33,[]);
                break;
            end
            PRN_a = num2bits(cfg.ReducedAlmanac.Almanac(iAlm).PRNa,8,1);
            delta_A = num2bits(cfg.ReducedAlmanac.Almanac(iAlm).delta_A,8,1);
            Omega0 = num2bits(cfg.ReducedAlmanac.Almanac(iAlm).Omega0,7,1);
            Phi0 = num2bits(cfg.ReducedAlmanac.Almanac(iAlm).Phi0,7,1);
            L1Health = cfg.ReducedAlmanac.Almanac(iAlm).L1Health;
            L2Health = cfg.ReducedAlmanac.Almanac(iAlm).L2Health;
            L5Health = cfg.ReducedAlmanac.Almanac(iAlm).L5Health;
            almPackets(:,iALM) = [PRN_a;delta_A;Omega0;Phi0;L1Health;L2Health;L5Health];
        end
        d = [WN_a;t_oa;almPackets(:);zeros(17,1)];
    case 4 % midi-almanac
        WN_a = num2bits(almWeekNum,13,1);
        t_oa = num2bits(almTimeOfApplicability,8,2^12);
        PRNa = num2bits(almStruct.PRNNumber,8,1);
        L1Health = almStruct.L1Health;
        L2Health = almStruct.L2Health;
        L5Health = almStruct.L5Health;
        e = num2bits(almStruct.Eccentricity,11,2^-16);
        deltai0 = num2bits(almStruct.InclinationOffset,11,2^-14);
        OmegaDot = num2bits(almStruct.RateOfRightAscension,11,2^-33);
        sqrtA = num2bits(almStruct.SqrtOfSemiMajorAxis,17,2^-4);
        Omega = num2bits(almStruct.GeographicLongitudeOfOrbitalPlane,16,2^-15);
        omega = num2bits(almStruct.ArgumentOfPerigee,16,2^-15);
        M0 = num2bits(almStruct.MeanAnomaly,16,2^-15);
        af0 = num2bits(almStruct.ZerothOrderClockCorrection,11,2^-20);
        af1 = num2bits(almStruct.FirstOrderClockCorrection,10,2^-37);
        d = [WN_a;t_oa;PRNa;L1Health;L2Health;L5Health;e;deltai0;OmegaDot; ...
            sqrtA;Omega;omega;M0;af0;af1;zeros(85,1)];
    case 5
        t_opD = num2bits(cfg.DifferentialCorrection.ReferenceTimeDCDataPredict,11,300);
        t_OD  = num2bits(cfg.DifferentialCorrection.ReferenceTimeDCData,11,300);
        dcDataType = dcParamStruct.DCDataType;

        % Clock differential correction (CDC) parameters
        cdcPRN = num2bits(dcParamStruct.CDCPRNID,8,1);
        delta_af0 = num2bits(dcParamStruct.SVClockBiasCoefficient,13,2^-35);
        delta_af1 = num2bits(dcParamStruct.SVClockDriftCorrection,8,2^-51);
        UDRAID = num2bits(dcParamStruct.UDRAID,5,1);

        % Ephemeris differential correction (EDC) parameters
        edcPRN = num2bits(dcParamStruct.EDCPRNID,8,1);
        Deltaa = num2bits(dcParamStruct.AlphaCorrection,14,2^-34);
        Deltab = num2bits(dcParamStruct.BetaCorrection,14,2^-34);
        Deltay = num2bits(dcParamStruct.GammaCorrection,15,2^-32);
        Deltai = num2bits(dcParamStruct.InclinationCorrection,12,2^-32);
        DeltaO = num2bits(dcParamStruct.RightAscensionCorrection,12,2^-32);
        DeltaA = num2bits(dcParamStruct.SemiMajorAxisCorrection,12,2^-9);
        UDRARateID = num2bits(dcParamStruct.UDRARateID,5,1);

        d = [t_opD;t_OD;dcDataType;cdcPRN;delta_af0;delta_af1;UDRAID; ...
            edcPRN;Deltaa;Deltab;Deltay;Deltai;DeltaO;DeltaA;UDRARateID;zeros(87,1)];

    case 6
        textPageID = num2bits(textPageCount,4,1);
        textMessageBits = int2bit(double(char(textMessage(:))),8);
        d = [textPageID;textMessageBits];
    case 7
        svconfigbits = zeros(3,63);
        cnt = 0;
        for iprn = svconfig(2,:)
            cnt = cnt + 1;
            svconfigbits(:,iprn) = int2bit(svconfig(1,cnt),3);
        end
        d = [svconfigbits(:);zeros(47,1)];
    case 8 % Integrity support message (ISM) used for advanced receiver autonomous integrity monitoring (ARAIM) algorithms
        GNSSID = num2bits(cfg.ISM.GNSSID,4,1);
        wn_ISM = num2bits(cfg.ISM.Weeknumber,13,1);
        tow_ISM = num2bits(cfg.ISM.TOW,6,4);
        t_correl = num2bits(cfg.ISM.CorrelationTimeConstantID,4,1);
        b_norm = num2bits(cfg.ISM.AdditiveTermID,4,1);
        gamma_norm = num2bits(cfg.ISM.ScalarTermID,4,1);
        R_sat = num2bits(cfg.ISM.SatelliteFaultRateID,4,1);
        P_const = num2bits(cfg.ISM.ConstellationFaultProbabilityID,4,1);
        MFD = num2bits(cfg.ISM.MeanFaultDurationID,4,1);
        serviceLevel = int2bit(cfg.ISM.ServiceLevel-1,3); % Service level can be from 1 to 4 as per standard
        mask = cfg.ISM.SatelliteInclusionMask(:); % Have as a column vector
        tempfiller = repmat([1;0],1,50);
        filler = tempfiller(1:91);
        ismcrcgen = comm.CRCGenerator(cfg.ISM.CRCPolynomial);
        ismBits = [GNSSID;wn_ISM;tow_ISM;t_correl;b_norm;gamma_norm;R_sat;P_const; ...
            MFD;serviceLevel;mask;filler(:)];
        d = ismcrcgen(ismBits);
    otherwise

end
bits = crcgenerator([prnid;pageNum;d]);
s3Bits = ldpcEncode(bits,cfgLDPC);
end

function ci = circIndices(ciLen,maxArrLen,numPagesComplete)

startIdx = mod(numPagesComplete*ciLen,maxArrLen)+1;
endIdx = startIdx + ciLen - 1;
ci = mod((startIdx:endIdx)-1,maxArrLen)+1;
end

function y = gpsTOIEnc(x)
msg = x(:).';
pns = comm.PNSequence('Polynomial',[1 1 0 0 1 1 1 1 1], ...
    'InitialConditions', fliplr(msg(2:end)),'SamplesPerFrame',51);

y = [msg(1); xor(msg(1),pns())];
end

function y = num2bits(x,n,s)
% Convert integers to bits by scaling the input integer
%
% Inputs:
%  x - Integer that needs to be converted to bits
%  n - Number of bits into which the integer must be converted
%  s - Scale factor
%
% Output:
%  y - Bits vector

y = int2bit(round(x./s),n);
end