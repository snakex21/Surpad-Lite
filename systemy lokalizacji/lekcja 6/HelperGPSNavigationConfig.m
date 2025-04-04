classdef HelperGPSNavigationConfig < comm.internal.ConfigBase
    %HelperGPSNavigationConfig GPS navigation data generation configuration
    %object
    %
    %   Note: This is a helper and its API and/or functionality may change
    %   in subsequent releases.
    %
    %   CFG = HelperGPSNavigationConfig creates a Global Positioning System
    %   (GPS) navigation data generation configuration object. The object
    %   contains the parameters required for generation of GPS navigation
    %   data bits. The parameters are described in detail in Appendix II
    %   and III of IS-GPS-200L [1].
    %
    %   CFG = HelperGPSNavigationConfig(Name,Value) creates a GPS
    %   navigation data object, CFG, with the specified property Name set
    %   to the specified Value. You can specify additional name-value pair
    %   arguments in any order as (Name1,Value1,...,NameN,ValueN).
    %
    %   HelperGPSNavigationConfig properties:
    %
    %   SignalType                        - Type of the navigation signal
    %   PRNID                             - Pseudo random noise index of
    %                                       satellite
    %   MessageTypes                      - CNAV data message types
    %   FrameIndices                      - LNAV data frame indices
    %   L1CSubframe3PageSequence          - Page sequence for subframe 3 in
    %                                       CNAV-2 data
    %   Preamble                          - Preamble of the navigation data
    %   TLMMessage                        - Telemetry message
    %   HOWTOW                            - Time of week in hand-over word
    %   L1CTOI                            - Time of interval value for L1C
    %   L1CITOW                           - Interval time of week for
    %                                       CNAV-2 data
    %   L1CHealth                         - Health of L1C signal
    %   AntiSpoofFlag                     - Anti spoof flag
    %   CodesOnL2                         - Ranging code on L2 band
    %   L2PDataFlag                       - Indication of presence of
    %                                       navigation data bits with
    %                                       P-code on L2 band
    %   L2CPhasing                        - Phase relationship indicator of
    %                                       L2C signal
    %   SVHealth                          - Satellite vehicle health
    %   SignalHealth                      - L1/L2/L5 signal health
    %                                       indicators
    %   IssueOfDataClock                  - Issue of data clock
    %   URAID                             - User range accuracy index
    %   WeekNumber                        - GPS week number
    %   GroupDelayDifferential            - Group delay differential
    %   SVClockCorrectionCoefficients     - Clock correction coefficients,
    %                                       af0, af1, af2
    %   ReferenceTimeOfClock              - Reference time of clock
    %   SemiMajorAxisLength               - Semi-major axis length of the
    %                                       satellite orbit
    %   ChangeRateInSemiMajorAxis         - Rate of change of semi-major
    %                                       axis length
    %   MeanMotionDifference              - Mean motion difference
    %   RateOfMeanMotionDifference        - Rate of change of mean motion
    %                                       difference
    %   FitIntervalFlag                   - Fit interval flag
    %   Eccentricity                      - Eccentricity of the satellite
    %                                       orbit
    %   MeanAnomaly                       - Mean anomaly at reference time
    %   ReferenceTimeOfEphemeris          - Reference time of ephemeris
    %   HarmonicCorrectionTerms           - Six harmonic correction terms
    %   IssueOfDataEphemeris              - Issue of data ephemeris
    %   IntegrityStatusFlag               - Integrity status flag
    %   ArgumentOfPerigee                 - Argument of perigee at
    %                                       reference time
    %   RateOfRightAscension              - Rate of right ascension
    %   LongitudeOfAscendingNode          - Longitude of ascending node
    %   Inclination                       - Inclination angle of the
    %                                       satellite orbit with respect to
    %                                       equator of Earth
    %   InclinationRate                   - Rate of change of inclination
    %                                       angle
    %   URAEDID                           - Elevation dependent user range
    %                                       accuracy index
    %   InterSignalCorrection             - Inter signal correction terms
    %   ISCL1CP                           - Inter signal correction for L1C
    %                                       pilot signal
    %   ISCL1CD                           - Inter signal correction for L1C
    %                                       data signal
    %   ReferenceTimeCEIPropagation       - Reference time of CEI
    %                                       propagation
    %   ReferenceWeekNumberCEIPropagation - Reference week number of CEI
    %                                       propagation
    %   URANEDID                          - Non-elevation dependent user
    %                                       range accuracy indices
    %   AlertFlag                         - Alert flag
    %   AgeOfDataOffset                   - Age of data offset
    %   NMCTAvailabilityIndicator         - NMCT availability indicator
    %   NMCTERD                           - NMCT ERD values
    %   AlmanacFileName                   - Almanac file name which has 
    %                                       almanac information in SEM
    %                                       format
    %   Ionosphere                        - Structure containing Ionosphere
    %                                       information
    %   EarthOrientation                  - Structure containing Earth's
    %                                       orientation information
    %   UTC                               - Structure containing UTC
    %                                       parameters
    %   DifferentialCorrection            - Structure containing
    %                                       differential correction
    %                                       parameters
    %   TimeOffset                        - Structure containing the
    %                                       parameters related to the time
    %                                       offset of GPS with respect to
    %                                       other GNSS systems
    %   TextMessage                       - Text message in LNAV data
    %   TextInMessageType36               - Text message in CNAV data
    %                                       message type 36
    %   TextInMessageType15               - Text message in CNAV data
    %                                       message type 15
    %   ISM                               - Integrity support message
    %
    %   References:
    %    [1]  IS-GPS-200, Rev: L. NAVSTAR GPS Space Segment/Navigation User
    %         Segment Interfaces. May 14, 2020; Code Ident: 66RP1.
    %
    %    [2] IS-GPS-800, Rev: J. NAVSTAR GPS Space Segment/User segment L1C
    %        Interfaces. Aug 22, 2022; Code Ident: 66RP1.

    %   Copyright 2021-2023 The MathWorks, Inc.

    properties
        %SignalType Data type of the navigation data
        %  Indicate the type of the signal as one of "CNAV" | "LNAV" |
        %  "CNAV2". The default is "CNAV".
        SignalType = "CNAV"
        %PRNID Pseudo random noise index of satellite
        %  Indicate the PRN ID of the satellite as an integer value from 1
        %  to 210. The default is 1.
        PRNID = 1
        %MessageTypes CNAV data message types
        %  Indicate the message types that needs to be transmitted in that
        %  order either as a column vector or a matrix with number of rows
        %  equal to 4. Navigation data generation happens by considering
        %  the message types as one column vector in column major form.
        %  This property is valid only when SignalType is "CNAV". The default
        %  is chosen such that transmission happens for 12 minutes and the
        %  default value obey the rules given in Section 30.3.4.1 of
        %  IS-GPS-200.
        MessageTypes = [10 11 37 30; 10 11 32 33; 10 11 12 37; 10 11 12 30; ...
            10 11 12 33; 10 11 12 37; 10 11 12 30; 10 11 32 33; 10 11 37 37; ...
            10 11 32 30; 10 11 12 33; 10 11 12 37; 10 11 12 30; 10 11 12 33; ...
            10 11 12 37].'
        %FrameIndices LNAV data frame indices
        %  Indicate the frame indices that needs to be transmitted in that
        %  order as a vector. This property is valid only when SignalType is
        %  set to "LNAV. The default is an array of integers from 1 to 25.
        FrameIndices = 1:25
        %L1CSubframe3PageSequence Page sequence for subframe 3 in CNAV-2
        %data
        %   Specify the page sequence of subframe 3 for CNAV-2 data. This
        %   property is valid only when SignalType is set to "CNAV2".
        L1CSubframe3PageSequence = [repmat(4,31,1); ... % Almanac
            7; ... % SV Configuration
            1; 2; 3; 8; ...
            repmat(5,10,1); ... % Differential correction parameters
            repmat(6,3,1)] % Text message
        %Preamble Preamble of the navigation data
        %  Indicate the preamble that needs to be transmitted in the
        %  navigation data. The default is 139. This property is active
        %  when SignalType is set to "LNAV".
        Preamble = 139
        %TLMMessage Telemetry message
        %  Indicate the telemetry message that needs to be transmitted in
        %  the LNAV data. This property is valid only when SignalType is set
        %  to "LNAV". The default is 0.
        TLMMessage = 0
        %HOWTOW Time of week in hand-over word
        %  Indicate the MSB 17 bits of the time of week value as an
        %  integer. The default is 1.
        HOWTOW = 1
        %L1CTOI Time of interval value for CNAV-2 data
        %    Specify the time of interval for CNAV-2 data. This property is
        %    valid only when SignalType is set to "CNAV2". The default is
        %    0.
        L1CTOI = 0
        %L1CITOW Interval time of week for CNAV-2 data
        %   Specify the internal time of week (ITOW) for CNAV-2 data. This
        %   represents the number of two hour epochs elapsed from the start
        %   of the week. This property is valid only when SignalType is set
        %   to "CNAV2". The default is 0.
        L1CITOW = 0
        %L1CHealth Health of L1C signal
        %   Specify the health flag of the L1C signal. Zero means that the
        %   signal is healthy. This property is valid only when SignalType
        %   is set to "CNAV2". The default is 0.
        L1CHealth = 0 % 0 --> healthy
        %AntiSpoofFlag Anti spoof flag
        %  Indicate the anti spoof flag as a binary value. The default is
        %  0.
        AntiSpoofFlag = 0
        %CodesOnL2 Ranging code on L2 band
        %  Indicate the codes on L2 band as one of "P-code" | "C/A-code".
        %  The default is "P-code".
        CodesOnL2 = "P-code"
        %L2PDataFlag Indication of presence of navigation data bits with
        %P-code on L2 band
        %  Indicate the presence of navigation data bits with P-code on L2
        %  band as a binary value. Value of 1 indicates navigation data Off
        %  on P-code of in-phase component of L2 channel. The default is 0.
        L2PDataFlag = 0
        %L2CPhasing Phase relationship indicator of L2C signal
        %  Indicate the phase relationship on L2C signal as a binary value.
        %  Value of 0 indicates that the L2C signal is on phase quadrature.
        %  A value of 1 indicates that L2C signal is in-phase. The default
        %  is 0.
        L2CPhasing = 0
        %SVHealth Satellite vehicle health
        %  Indicate the satellite health as an integer value. This property
        %  is valid only when SignalType is set to "LNAV". The default is 0.
        SVHealth = 0
        %SignalHealth L1/L2/L5 signal health indicators.
        %  Indicate the signal health of L1/L2/L5 as a three element array
        %  of binary values. This property is valid only when SignalType is
        %  set to "CNAV". The default is a 3 element column vector of
        %  zeros.
        SignalHealth = [0; 0; 0]
        %IssueOfDataClock Issue of data clock
        %  Indicate the issue of data clock as an integer value. In the
        %  encoded message, this value is going to be of 10 bits. This
        %  property is valid only when SignalType is set to "LNAV". The
        %  default is 0.
        IssueOfDataClock = 0
        %URAID User range accuracy index
        %  Indicate the user range accuracy as an integer for LNAV data.
        %  This property is valid only when SignalType is set to "LNAV". The
        %  default is 0.
        URAID = 0
        %WeekNumber GPS week number
        %  Specify the GPS week number as an integer value. The default
        %  is 2149.
        WeekNumber = 2149
        %GroupDelayDifferential Group delay differential
        %  Indicate the group delay differential value in seconds. The
        %  default is 0.
        GroupDelayDifferential = 0 % T_GD
        %SVClockCorrectionCoefficients Clock correction coefficients, af0,
        %af1, af2
        %  Indicate the satellite vehicle (SV) clock bias (af0), clock
        %  drift (af1) and clock drift rate (af2) in that order as an array
        %  of three elements. The default is a 3 element column vector with
        %  all zeros.
        SVClockCorrectionCoefficients = [0; 0; 0] % [af0; af1; af2]
        %ReferenceTimeOfClock Reference time of clock
        %  Indicate the reference time of clock in seconds. The default is
        %  0.
        ReferenceTimeOfClock = 0 % t_oc
        %SemiMajorAxisLength Semi-major axis length of the satellite orbit
        %  Indicate the semi-major axis length of the satellite orbit as a
        %  scalar double value in meters. The default is 26560000.
        SemiMajorAxisLength = 26560000
        %ChangeRateInSemiMajorAxis Rate of change of semi-major axis length
        %  Indicate the rate of change of semi-major axis length in meters
        %  per second. This property is valid only when SignalType is set to
        %  "CNAV". The default is 0.
        ChangeRateInSemiMajorAxis = 0
        %MeanMotionDifference Mean motion difference
        %  Indicate the mean motion difference value as a scalar double.
        %  The default is 0.
        MeanMotionDifference = 0
        %RateOfMeanMotionDifference Rate of change of mean motion
        %difference
        %  Indicate the rate of change of mean motion difference as a
        %  scalar double value. This property is valid only when SignalType
        %  is set to "CNAV". The default is 0.
        RateOfMeanMotionDifference = 0
        %FitIntervalFlag Fit interval flag
        %  Indicate the fit interval flag as a binary value. This property
        %  is valid only when SignalType is set to "LNAV". The default is 0.
        FitIntervalFlag = 0
        %Eccentricity Eccentricity of the satellite orbit
        %  Indicate the eccentricity of the ellipse in which satellite
        %  orbits as a scalar double value in the range of 0 to 1. The
        %  default is 0.02.
        Eccentricity = 0.02
        %MeanAnomaly Mean anomaly at reference time
        %  Indicate the mean anomaly value as a scalar double value. The
        %  default is 0.
        MeanAnomaly = 0
        %ReferenceTimeOfEphemeris Reference time of ephemeris
        %  Indicate the reference time of ephemeris as a scalar double
        %  value. This value indicates the time within a week when the
        %  ephemeris data is updated in seconds. The default is 0.
        ReferenceTimeOfEphemeris = 0 % t_oe
        %HarmonicCorrectionTerms Six harmonic correction terms
        %  Indicate the six harmonic correction terms as a vector of 6
        %  elements. First element is the amplitude of the sine harmonic
        %  correction term to the angle of inclination (C_is). Second
        %  element is the amplitude of the cosine harmonic correction term
        %  to the angle of inclination (C_ic). The third element is the
        %  amplitude of the sine correction term to the orbit radius
        %  (C_rs). The fourth element is the Amplitude of the cosine
        %  correction term to the orbit radius (C_rc). The fifth element is
        %  the amplitude of the sine harmonic correction term to the
        %  argument of latitude (C_us). The sixth element is the amplitude
        %  of the cosine harmonic correction term to the argument of
        %  latitude (C_uc). The default is a column vector of six zeros.
        HarmonicCorrectionTerms = zeros(6,1) % [Cis; Cic; Crs; Crc; Cus; Cuc]
        %IssueOfDataEphemeris Issue of data ephemeris
        %  Indicate the issue of data ephemeris as a scalar integer value.
        %  This property is valid only when SignalType is set to "LNAV". The
        %  default is 0.
        IssueOfDataEphemeris = 0
        %IntegrityStatusFlag Integrity status flag
        %  Indicate the signal integrity status as a binary scalar value.
        %  The default is 0.
        IntegrityStatusFlag = 0
        %ArgumentOfPerigee Argument of perigee at reference time
        %  Indicate the argument of perigee of the satellite orbit as a
        %  scalar double value in the units of semi-circles. Argument of
        %  perigee is defined as the angle subtended by the direction of
        %  longitude of ascending node to the perigee. The default is
        %  -0.52.
        ArgumentOfPerigee = -0.52
        %RateOfRightAscension Rate of right ascension
        %  Indicate the rate of change of right ascension as a scalar
        %  double value. The default is 0.
        RateOfRightAscension = 0
        %LongitudeOfAscendingNode Longitude of ascending node
        %  Indicate the longitude of ascending node as a scalar double
        %  value. The default is -0.84.
        LongitudeOfAscendingNode = -0.84
        %Inclination Inclination angle of the satellite orbit with respect
        %to equator of Earth
        %  Indicate the inclination angle as a scalar double value in the
        %  units of semi-circles. The default is 0.3.
        Inclination = 0.3 % In semi-circles
        %InclinationRate Rate of change of inclination angle
        %  Indicate the rate of change of inclination angle as a scalar
        %  double in the units of semi-circles/second. The default is 0.
        InclinationRate = 0
        %URAEDID Elevation dependent (ED) user range accuracy (URA) index
        %   Indicate the elevation dependent user range accuracy index as
        %   an integer. This property is valid only when SignalType is set to
        %   "CNAV". The default is 0.
        URAEDID = 0
        %InterSignalCorrection Inter signal correction terms
        %  Indicate the inter signal correction (ISC) terms as a vector of
        %  4 elements. First element represents ISC L1C/A. Second element
        %  represents ISC L2C. Third element represents ISC L5I5. Fourth
        %  element represents ISC L5Q5. This property is valid only when
        %  SignalType is set to "CNAV". The default is a column vector of 4
        %  zeros.
        InterSignalCorrection = zeros(4,1) % [L1C/A; L2C; L5I5; L5Q5]
        %ISCL1CP Inter signal correction for L1C pilot signal
        ISCL1CP = 0
        %ISCL1CD Inter signal correction for L1C data signal
        ISCL1CD = 0
        %ReferenceTimeCEIPropagation Reference time of CEI propagation
        %  Indicate the reference time of CEI propagation as a scalar
        %  double value. This property is valid only when SignalType is set
        %  to "CNAV". The default value is 0.
        ReferenceTimeCEIPropagation = 0 % t_op
        %ReferenceWeekNumberCEIPropagation Reference week number of CEI
        %propagation
        %  Indicate the reference week number of clock, ephemeris, and
        %  integrity (CEI) parameters propagation. This property is valid
        %  only when SignalType is set to "CNAV". The default is 101.
        ReferenceWeekNumberCEIPropagation = 101 % WN_OP
        %URANEDID Non-elevation dependent user range accuracy indices
        %  Indicate the Non-elevation dependent user range accuracy indices
        %  as a vector of three elements. The default is a column vector of
        %  3 zeros.
        URANEDID = [0; 0 ; 0] % [URA_NED0; URA_NED1; URA_NED2]
        %AlertFlag Alert flag
        %  Indicate the alert flag as a binary scalar value. The default is
        %  0.
        AlertFlag = 0
        %AgeOfDataOffset Age of data offset
        %  Indicate the age of data in seconds. The default is 0.
        AgeOfDataOffset = 0 % In seconds
        %NMCTAvailabilityIndicator NMCT availability indicator
        %  Indicate the presence of NMCT as a binary value. The default is
        %  0.
        NMCTAvailabilityIndicator = 0
        %NMCTERD NMCT ERD values
        %  Indicate the NMCT estimated rate deviation (ERD) values as an
        %  array of 30 elements. The default is a column vector of 30
        %  zeros.
        NMCTERD = zeros(30,1)
        %AlmanacFileName  Almanac file name which has almanac information
        %in SEM format
        %  Indicate the almanac file name as a string scalar or a character
        %  vector. The default is "gpsAlmanac.txt".
        AlmanacFileName = "gpsAlmanac.txt"
        %Ionosphere Structure containing Ionosphere information
        %  Indicate the ionospheric parameters as a structure with fields
        %  "Alpha" and "Beta". The default of each field of the structure
        %  is a column vector of 4 zeros.
        Ionosphere = struct('Alpha',zeros(4,1),'Beta',zeros(4,1))
        %EarthOrientation Structure containing Earth's orientation
        %information
        %  Indicate the Earth orientation parameters as structure with
        %  fields "ReferenceTimeEOP", "XAxisPolarMotionValue",
        %  "XAxisPolarMotionDrift", "YAxisPolarMotionValue",
        %  "YAxisPolarMotionDrift", "UT1_UTCDifference",
        %  "RateOfUT1_UTCDifference". The default value of each of these
        %  properties is 0.
        EarthOrientation = struct('ReferenceTimeEOP',0,'XAxisPolarMotionValue',0,...
            'XAxisPolarMotionDrift',0,'YAxisPolarMotionValue',0, ...
            'YAxisPolarMotionDrift',0,'UT1_UTCDifference',0, ...
            'RateOfUT1_UTCDifference',0);
        %UTC Structure containing UTC parameters
        %  Indicate the parameters of coordinated universal time (UTC) as a
        %  structure with fields "UTCTimeCoefficients",
        %  "PastLeapSecondCount", "ReferenceTimeUTCData",
        %  "TimeDataReferenceWeekNumber", "LeapSecondReferenceWeekNumber",
        %  "LeapSecondReferenceDayNumber", "FutureLeapSecondCount".
        UTC = struct('UTCTimeCoefficients',[0 0 0],'PastLeapSecondCount',18, ...
            'ReferenceTimeUTCData',0,'TimeDataReferenceWeekNumber', 2149, ...
            'LeapSecondReferenceWeekNumber',2149,'LeapSecondReferenceDayNumber',1, ...
            'FutureLeapSecondCount',18)
        %DifferentialCorrection Structure containing differential
        %correction parameters
        %  Indicate the differential correction parameters as a structure
        %  with fields "ReferenceTimeDCDataPredict", "ReferenceTimeDCData",
        %  "Data". The filed "Data" is an array of structure with fields
        %  "DCDataType", "CDCPRNID", "SVClockBiasCoefficient",
        %  "SVClockDriftCorrection", "UDRAID", "EDCPRNID",
        %  "AlphaCorrection", "BetaCorrection", "GammaCorrection",
        %  "InclinationCorrection", "RightAscensionCorrection",
        %  "SemiMajorAxisCorrection", "UDRARateID".
        DifferentialCorrection = struct('ReferenceTimeDCData',0, ...
            'ReferenceTimeDCDataPredict',0, ...
            'Data',repmat(struct('DCDataType',0,'CDCPRNID',1,'SVClockBiasCoefficient',0, ...
            'SVClockDriftCorrection',0,'UDRAID',1,'EDCPRNID',1, ...
            'AlphaCorrection',0,'BetaCorrection',0,'GammaCorrection',0, ...
            'InclinationCorrection',0,'RightAscensionCorrection',0, ...
            'SemiMajorAxisCorrection',0,'UDRARateID',0),31,1))
        %TimeOffset Structure containing the parameters related to the time
        %offset of GPS with respect to other GNSS systems
        %  Indicate the time offset of GPS constellation with respect to
        %  other GNSS constellation as a structure with fields
        %  "ReferenceTimeGGTO", "WeekNumberGGTO", "GNSSID",
        %  "GGTOCoefficients".
        TimeOffset = struct('ReferenceTimeGGTO',0,'WeekNumberGGTO',101, ...
            'GNSSID',0,'GGTOCoefficients',[0;0;0])
        %ReducedAlmanac Reduced almanac used in modernized GPS signals
        ReducedAlmanac = struct('WeekNumber',1,'ReferenceTimeOfAlmanac',0, ...
            'Almanac',repmat(struct('PRNa',0,'delta_A',0,'Omega0',0, ...
            'Phi0',0,'L1Health',0,'L2Health',0,'L5Health',0),6,1)) % Reduced almanac 
        %TextMessage Text message in LNAV data
        %  Indicate the text message that needs to be transmitted on the
        %  LNAV data. It is of length 22 characters. If more characters is
        %  specified, then the text is snipped to 22 characters. If less
        %  than 22 characters is specified, then the additional characters
        %  are filled with blank spaces. The default is 'This content is
        %  part of Satellite Communications Toolbox'.
        TextMessage = 'This content is part of Satellite Communications Toolbox. Thank you. '
        %TextInMessageType36 Text message in CNAV data message type 36
        %  Indicate the text message that needs to be transmitted on the
        %  CNAV data. It is of length 18 characters. If more characters is
        %  specified, then the text is snipped to 18 characters. If less
        %  than 18 characters is specified, then the additional characters
        %  are filled with blank spaces. The default is 'This content is
        %  part of Satellite Communications Toolbox'.
        TextInMessageType36 = 'This content is part of Satellite Communications Toolbox. '
        %TextInMessageType15 Text message in CNAV data message type 15
        %  Indicate the text message that needs to be transmitted on the
        %  CNAV data. It is of length 29 characters. If more characters is
        %  specified, then the text is snipped to 29 characters. If less
        %  than 29 characters is specified, then the additional characters
        %  are filled with blank spaces. The default is 'This content is
        %  part of Satellite Communications Toolbox'.
        TextInMessageType15 = 'This content is part of Satellite Communications Toolbox. '
        %ISM Integrity support message
        ISM = struct('GNSSID',4, ... % 4 is GPS
            'Weeknumber',1,'TOW',0,'CorrelationTimeConstantID',0,'AdditiveTermID',0, ...
            'ScalarTermID',0,'SatelliteFaultRateID',0,'ConstellationFaultProbabilityID',0, ...
            'MeanFaultDurationID',0,'ServiceLevel',1,'SatelliteInclusionMask',zeros(63,1), ...
            'CRCPolynomial','x^32 + x^31 + x^24 + x^22 + x^16 + x^14 + x^8 + x^7 + x^5 + x^3 + x + 1');
    end

    properties(Hidden)
        PageID % Useful while generating the GPS data frame with LNAV data
        SubframeID % Useful while generating LNAV data
    end

    properties(Constant,Hidden)
        SignalType_Values = {'CNAV','CNAV2','LNAV'}
        CodesOnL2_Values = {'P-code','C/A-code','invalid'}
    end

    methods
        function obj = HelperGPSNavigationConfig(varargin)
            %HelperGPSNavigationParameters Construct an instance of this class
            %   Support name-value pair arguments when constructing object.
            obj@comm.internal.ConfigBase(varargin{:});
        end

        % Set methods for independent properties validation
        function obj = set.SignalType(obj,val)
            prop = 'SignalType';
            val = validateEnumProperties(obj, prop, val);
            obj.(prop) = string(val);
        end

        function obj = set.PRNID(obj,val)
            prop = 'PRNID';
            validateattributes(val,{'double','single','uint8'},{'positive','integer','scalar','>=',1,'<=',210},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.MessageTypes(obj,val)
            prop = 'MessageTypes';
            validateattributes(val,{'double','single','uint8'},{'positive','integer'})
            if ~any(any(ismember(val,[10;11;30;31;32;33;34;35;36;37;12;13;14;15])))
                error('All elements in the MessageTypes property must be from the set {10,11,12,13,14,15,30,31,32,33,34,35,36,37}.')
            end
            obj.(prop) = val;
        end

        function obj = set.FrameIndices(obj,val)
            prop = 'FrameIndices';
            validateattributes(val,{'double','single','uint8'},{'positive','integer','<=',25},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.Preamble(obj,val)
            prop = 'Preamble';
            validateattributes(val,{'double','single','uint8'},{'nonnegative','integer'},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.TLMMessage(obj,val)
            prop = 'TLMMessage';
            validateattributes(val,{'double','single','uint16'},{'nonnegative','integer'},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.HOWTOW(obj,val)
            prop = 'HOWTOW';
            validateattributes(val,{'double','single','uint32'},{'nonnegative','integer'})
            obj.(prop) = val;
        end

        function obj = set.AntiSpoofFlag(obj,val)
            prop = 'AntiSpoofFlag';
            validateattributes(val,{'double','logical'},{'binary'})
            obj.(prop) = val;
        end

        function obj = set.CodesOnL2(obj,val)
            prop = 'CodesOnL2';
            val = validateEnumProperties(obj, prop, val);
            obj.(prop) = val;
        end

        function obj = set.L2PDataFlag(obj,val)
            prop = 'L2PDataFlag';
            validateattributes(val,{'double','logical'},{'binary'},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.L2CPhasing(obj,val)
            prop = 'L2CPhasing';
            validateattributes(val,{'double','logical'},{'binary'},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.AgeOfDataOffset(obj,val)
            prop = 'AgeOfDataOffset';
            validateattributes(val,{'double','single'},{'nonnegative','<=',27900},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.NMCTAvailabilityIndicator(obj,val)
            prop = 'NMCTAvailabilityIndicator';
            validateattributes(val,{'double','logical'},{'binary'},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.NMCTERD(obj,val)
            prop = 'NMCTERD';
            validateattributes(val,{'double','single','uint32'},{'vector','numel',30},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.AlmanacFileName(obj,val)
            prop = 'AlmanacFileName';
            validateattributes(val,{'char','string'},{},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.Ionosphere(obj,val)
            prop = 'Ionosphere';
            validateattributes(val,{'struct'},{},mfilename,prop)
            validateattributes(val.Alpha,{'double','single'},{'vector','numel',4},mfilename,[prop '.Alpha'])
            validateattributes(val.Beta,{'double','single'},{'vector','numel',4},mfilename,[prop '.Beta'])
            obj.(prop) = val;
        end

        function obj = set.EarthOrientation(obj,val)
            prop = 'EarthOrientation';
            validateattributes(val,{'struct'},{},mfilename,prop)
            validateattributes(val.ReferenceTimeEOP,{'double','single'},{'nonnegative','scalar','<=',604784},mfilename,[prop '.ReferenceTimeEOP'])
            validateattributes(val.XAxisPolarMotionValue,{'double','single'},{},mfilename,[prop '.XAxisPolarMotionValue'])
            validateattributes(val.XAxisPolarMotionDrift,{'double','single'},{},mfilename,[prop '.XAxisPolarMotionDrift'])
            validateattributes(val.YAxisPolarMotionValue,{'double','single'},{},mfilename,[prop '.YAxisPolarMotionValue'])
            validateattributes(val.YAxisPolarMotionDrift,{'double','single'},{},mfilename,[prop '.YAxisPolarMotionDrift'])
            validateattributes(val.UT1_UTCDifference,{'double','single'},{},mfilename,[prop '.UT1_UTCDifference'])
            validateattributes(val.RateOfUT1_UTCDifference,{'double','single'},{},mfilename,[prop '.RateOfUT1_UTCDifference'])
            obj.(prop) = val;
        end

        function obj = set.UTC(obj,val)
            prop = 'UTC';
            validateattributes(val,{'struct'},{},mfilename,prop)
            validateattributes(val.UTCTimeCoefficients,{'double','single'},{'vector'},mfilename,[prop '.UTCTimeCoefficients'])
            validateattributes(val.PastLeapSecondCount,{'double','single'},{},mfilename,[prop '.PastLeapSecondCount'])
            validateattributes(val.ReferenceTimeUTCData,{'double','single'},{},mfilename,[prop '.ReferenceTimeUTCData'])
            validateattributes(val.TimeDataReferenceWeekNumber,{'double','single'},{},mfilename,[prop '.TimeDataReferenceWeekNumber'])
            validateattributes(val.LeapSecondReferenceWeekNumber,{'double','single'},{},mfilename,[prop '.LeapSecondReferenceWeekNumber'])
            validateattributes(val.FutureLeapSecondCount,{'double','single'},{},mfilename,[prop '.FutureLeapSecondCount'])
            obj.(prop) = val;
        end

        function obj = set.DifferentialCorrection(obj,val)
            prop = 'DifferentialCorrection';
            validateattributes(val,{'struct'},{},mfilename,prop)
            validateattributes(val.Data,{'struct'},{},mfilename,prop)
            validateattributes(val.ReferenceTimeDCDataPredict,{'double','single'},{'nonnegative','scalar','<=',604500},mfilename,[prop '.ReferenceTimeDCDataPredict'])
            validateattributes(val.ReferenceTimeDCData,{'double','single'},{'nonnegative','scalar','<=',604500},mfilename,[prop '.ReferenceTimeDCData'])
            obj.(prop) = val;
        end

        function obj = set.TimeOffset(obj,val)
            prop = 'TimeOffset';
            validateattributes(val,{'struct'},{},mfilename,prop)
            validateattributes(val.ReferenceTimeGGTO,{'double','single'},{'nonnegative','scalar','<=',604784},mfilename,[prop '.ReferenceTimeGGTO'])
            validateattributes(val.WeekNumberGGTO,{'double','single','uint16'},{'nonnegative','scalar'},mfilename,[prop '.WeekNumberGGTO'])
            validateattributes(val.GNSSID,{'double','single','uint8'},{'nonnegative','scalar','<=',7},mfilename,[prop '.GNSSID'])
            validateattributes(val.GGTOCoefficients,{'double','single'},{'vector','numel',3},mfilename,[prop '.GGTOCoefficients'])
            obj.(prop) = val;
        end

        function obj = set.TextMessage(obj,val)
            prop = 'TextMessage';
            validateattributes(val,{'char','string'},{},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.TextInMessageType36(obj,val)
            prop = 'TextInMessageType36';
            validateattributes(val,{'char','string'},{},mfilename,prop)
            obj.(prop) = val;
        end

        function obj = set.TextInMessageType15(obj,val)
            prop = 'TextInMessageType15';
            validateattributes(val,{'char','string'},{},mfilename,prop)
            obj.(prop) = val;
        end
    end

    methods(Access = protected)
        function flag = isInactiveProperty(obj,prop)
            flag = true;
            visiblePropListLNAV = {'SignalType','PRNID','FrameIndices','TLMMessage', ...
                'HOWTOW','AntiSpoofFlag','CodesOnL2','L2PDataFlag','SVHealth', ...
                'IssueOfDataClock','URAID','WeekNumber','GroupDelayDifferential', ...
                'SVClockCorrectionCoefficients','ReferenceTimeOfClock', ...
                'SemiMajorAxisLength','MeanMotionDifference','FitIntervalFlag', ...
                'Eccentricity','MeanAnomaly','ReferenceTimeOfEphemeris','HarmonicCorrectionTerms', ...
                'IssueOfDataEphemeris','IntegrityStatusFlag','ArgumentOfPerigee', ...
                'RateOfRightAscension','LongitudeOfAscendingNode','Inclination', ...
                'InclinationRate','AlertFlag','AgeOfDataOffset','NMCTAvailabilityIndicator', ...
                'NMCTERD','AlmanacFileName','Ionosphere','UTC','TextMessage'};
            visiblePropListCNAV = {'SignalType','PRNID','MessageTypes','HOWTOW', ...
                'L2CPhasing','SignalHealth','WeekNumber','GroupDelayDifferential', ...
                'ReferenceTimeOfClock','SemiMajorAxisLength','ChangeRateInSemiMajorAxis', ...
                'MeanMotionDifference','RateOfMeanMotionDifference','Eccentricity', ...
                'MeanAnomaly','ReferenceTimeOfEphemeris','HarmonicCorrectionTerms', ...
                'IntegrityStatusFlag','ArgumentOfPerigee','RateOfRightAscension', ...
                'LongitudeOfAscendingNode','Inclination','InclinationRate', ...
                'URAEDID','InterSignalCorrection','ReferenceTimeCEIPropagation', ...
                'ReferenceWeekNumberCEIPropagation','URANEDID','AlertFlag', ...
                'AgeOfDataOffset','AlmanacFileName','Ionosphere','EarthOrientation', ...
                'UTC','DifferentialCorrection','TimeOffset','ReducedAlmanac', ...
                'TextInMessageType36','TextInMessageType15'};
            visiblePropListCNAV2 = {'SignalType','PRNID','L1CSubframe3PageSequence', ...
                'L1CTOI','L1CITOW','L1CHealth','WeekNumber','GroupDelayDifferential', ...
                'SemiMajorAxisLength','ChangeRateInSemiMajorAxis','MeanMotionDifference', ...
                'RateOfMeanMotionDifference','Eccentricity','MeanAnomaly','ReferenceTimeOfEphemeris', ...
                'HarmonicCorrectionTerms','IntegrityStatusFlag','ArgumentOfPerigee', ...
                'RateOfRightAscension','LongitudeOfAscendingNode','Inclination', ...
                'InclinationRate','URAEDID','InterSignalCorrection','ISCL1CP', ...
                'ISCL1CD','ReferenceTimeCEIPropagation','ReferenceWeekNumberCEIPropagation', ...
                'URANEDID','AlmanacFileName','Ionosphere','EarthOrientation', ...
                'UTC','DifferentialCorrection','TimeOffset','ReducedAlmanac','TextMessage','ISM'};

            if strcmp(obj.SignalType,'LNAV')
                flag = ~any(strcmp(prop,visiblePropListLNAV));
            elseif strcmp(obj.SignalType,'CNAV')
                flag = ~any(strcmp(prop,visiblePropListCNAV));
            elseif strcmp(obj.SignalType,'CNAV2')
                flag = ~any(strcmp(prop,visiblePropListCNAV2));
            end
        end
    end
end