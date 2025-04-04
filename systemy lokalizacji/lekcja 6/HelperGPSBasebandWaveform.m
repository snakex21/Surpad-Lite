function iq = HelperGPSBasebandWaveform(IQContent, pgen, PRNID, CLCodeIdx, D, Dc)
%HelperGPSBasebandWaveform Generate GPS waveform
%
%   Note: This is a helper and its API and/or functionality may change
%   in subsequent releases.
%
%   IQ = HelperGPSBasebandWaveform(IQCONTENT,PGEN,PRNID,CLCODEIDX,D,DC)
%   generates the baseband GPS waveform samples, IQ. IQCONTENT is a 2
%   element string vector. First element of this vector indicates the
%   possible data transmitted on In-phase branch, and the second element
%   indicates the possible values transmitted on Quadrature-phase branch of
%   the baseband waveform. PGEN is the GPS P-code generator System object
%   of type gpsPCode. PRNID is the pseudo-random noise (PRN) index for
%   which signal must be generated. CLCODEIDX is the index of CL-code in
%   the chunks of 10230 chips. As CL-code is of length 767250 chips, for
%   every 75 (75*10230 = 76250) steps of CLCODEIDX, CLCODEIDX gets reset to
%   zero. D is one LNAV data bit and DC is one CNAV data bit.
%
%   References:
%    [1] IS-GPS-200L. "NAVSTAR GPS Space Segment/Navigation User Segment
%        Interfaces." GPS Enterprise Space & Missile Systems Center (SMC) -
%        LAAFB, May 14, 2020.
%
%   See also HelperGPSNavigationConfig, HelperGPSCEIConfig,
%   HelperGPSNAVDataEncode.

%   Copyright 2021-2022 The MathWorks, Inc.

persistent caCode cmCode clCode localPRN
if isempty(localPRN)
    localPRN = PRNID;
end
if localPRN ~= PRNID || isempty(caCode)
    caCode = gnssCACode(PRNID,'GPS');
    % Use row vector for CM/CL-code processing
    cmCode = HelperGPSL2CRangingCode(PRNID,'CM').';
    clCode = HelperGPSL2CRangingCode(PRNID,'CL').';
    localPRN = PRNID;
end
IBranchContent = IQContent(1);
QBranchContent = IQContent(2);
LNAVFlag = any(strcmp(IBranchContent,["P(Y) + D","C/A + D"])) || ...
    strcmp(QBranchContent,"C/A + D");
% Check if C/A-code must be transmitted based on configuration
isCACode = any(strncmpi("C/A",[IBranchContent, QBranchContent],3));
% Check if P-code must be transmitted based on configuration
isPCode = strncmpi("P",IBranchContent,1);
% Check if CM/CL-code must be transmitted based on configuration
isCMCLCode = strncmpi("L2",QBranchContent,2);
% Number of P-code chips per NAV data bit is 204600
numSampesPerDataBit = 204600;
% Pre-initialize the Q branch data to deal with "None" option available on
% L2-band
QBranchData = zeros(numSampesPerDataBit,1);
% Time taken to transmit one NAV data bit corresponds to 10230 chips of
% CM/CL-code
numCMCLChipsPerDataBit = 10230;
% Check if C/A-code exists in the waveform and generate C/A-code data bits
if isCACode
    % Each NAV data bit corresponds to 20 repetitions of C/A-code
    tempCABits = repmat(caCode,20,1);
    if LNAVFlag
        tempCABits = xor(tempCABits,D);
    end
    % Rate match with P-code. Each C/A-code chip time corresponds to 10
    % P-code chips
    tempBits = repmat(tempCABits.',10,1);
    caBits = tempBits(:);
    if strncmpi("C/A",IBranchContent,3) % Compare first 3 characters
        IBranchData = 1-2*caBits;
    else % Q-phase
        QBranchData = 1-2*caBits;
    end
end

% Check if P-code exists in the waveform and generate P-code data
% bits
if isPCode
    pBits = pgen();
    if LNAVFlag
        pBits = xor(pBits,D);
    end
    IBranchData = 1-2*pBits; % If it is P-code, then it must be on I-phase
end

% Check if CM/CL-code exists in the waveform and generate the
% CM/CL-code data bits
if isCMCLCode
    cmWithData = xor(cmCode,Dc);
    clCodePart = clCode(CLCodeIdx*numCMCLChipsPerDataBit+1:((CLCodeIdx+1)* ...
        numCMCLChipsPerDataBit));
    tempCMCLBits = [cmWithData;clCodePart];

    % Bit-by-bit multiplexing of CM with data and CL-code and Upsample to
    % match the rate with P-code. Each CM/CL-code chip time corresponds to
    % 10 P-code chips
    cmclBits = repmat(tempCMCLBits(:).',10,1);
    QBranchData = 1-2*cmclBits(:); % If it is CM/CL-code, then it must be on Q-phase
end
iq = double(IBranchData(:)) + 1j*double(QBranchData(:));
end