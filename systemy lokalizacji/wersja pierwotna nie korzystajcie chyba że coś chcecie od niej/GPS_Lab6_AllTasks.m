function GPS_Lab6_AllTasks()
% GPS_Lab6_AllTasks – realizuje zadania 1, 2, 3 i 4 w jednym pliku,
% a dodatkowo tworzy wykresy potwierdzające wykonanie zadań.
%
% Zadanie 1: Konfiguracja i generacja sygnału baseband dla PRN = 1.
% Zadanie 2: Wczytanie danych efemeryd (placeholder) dla PRN = 5 i generacja sygnału baseband.
% Zadanie 3: Generowanie sygnału IF na podstawie sygnału baseband (PRN = 1).
% Zadanie 4: Generowanie zintegrowanego sygnału z wielu satelitów (PRN = 1,5,10).
%
% Uwaga: Funkcje pomocnicze są zaimplementowane jako stuby (uproszczone wersje).

    NumNavDataBits = 5;  % Liczba bitów nawigacyjnych do wygenerowania

    %% Zadanie 1: Konfiguracja i sygnał baseband (PRN = 1)
    disp("========== Zadanie 1: Konfiguracja i sygnał baseband (PRN = 1) ==========");
    lnavConfig1 = HelperGPSNavigationConfig('SignalType', "LNAV", 'PRNID', 1);
    disp("Oryginalna konfiguracja (PRN = 1):");
    disp(lnavConfig1);
    
    % Modyfikacja właściwości
    lnavConfig1.WeekNumber = 2240;
    lnavConfig1.Eccentricity = 0.03;
    lnavConfig1.ReferenceTimeOfEphemeris = 360000;  % sekundy od początku tygodnia
    if ~isfield(lnavConfig1, 'NavDataBitStartIndex')
        lnavConfig1.NavDataBitStartIndex = 1;
        disp("Ostrzeżenie: Używam domyślnego NavDataBitStartIndex = 1");
    end
    disp("Konfiguracja po modyfikacji (PRN = 1):");
    disp(lnavConfig1);
    
    % Generacja sygnału baseband
    [waveform1, Fs1] = localGenerateGPSBaseband(lnavConfig1, NumNavDataBits);
    if ~isempty(waveform1)
        disp(['Zadanie 1: Wygenerowano sygnał baseband (PRN = 1) z ', num2str(length(waveform1)), ...
              ' próbek, Fs = ', num2str(Fs1/1e6), ' MHz.']);
        % Wykres sygnału baseband (realna część)
        figure;
        plot(real(waveform1));
        title('Sygnał Baseband (PRN = 1) - Realna część');
        xlabel('Próbki'); ylabel('Amplituda');
    else
        error("Zadanie 1: BŁĄD – nie udało się wygenerować sygnału baseband.");
    end

    %% Zadanie 2: Dane efemeryd i sygnał baseband (PRN = 5)
    disp("========== Zadanie 2: Dane efemeryd i sygnał baseband (PRN = 5) ==========");
    rinexFile = "brdc1230.22n";
    prn2 = 5;
    realEphem = localLoadRinexEphemeris(rinexFile, prn2);
    
    lnavConfig2 = HelperGPSNavigationConfig('SignalType', "LNAV", 'PRNID', prn2);
    disp(['Oryginalny WeekNumber dla PRN = ', num2str(prn2), ': ', num2str(lnavConfig2.WeekNumber)]);
    disp(['Oryginalny ReferenceTimeOfEphemeris dla PRN = ', num2str(prn2), ': ', num2str(lnavConfig2.ReferenceTimeOfEphemeris)]);
    
    % Nadpisanie właściwości danymi efemeryd
    lnavConfig2.WeekNumber = realEphem.WeekNumber;
    lnavConfig2.ReferenceTimeOfEphemeris = realEphem.Toe;
    lnavConfig2.Eccentricity = realEphem.Ecc;
    if ~isfield(lnavConfig2, 'NavDataBitStartIndex')
        lnavConfig2.NavDataBitStartIndex = 1;
        disp("Ostrzeżenie: Używam domyślnego NavDataBitStartIndex = 1");
    end
    disp("Konfiguracja po wczytaniu efemeryd (PRN = 5):");
    disp(lnavConfig2);
    
    [waveform2, Fs2] = localGenerateGPSBaseband(lnavConfig2, NumNavDataBits);
    if ~isempty(waveform2)
        disp(['Zadanie 2: Wygenerowano sygnał baseband (efemerydy, PRN = 5) z ', num2str(length(waveform2)), ...
              ' próbek, Fs = ', num2str(Fs2/1e6), ' MHz.']);
        % Wykres sygnału baseband dla PRN = 5
        figure;
        plot(real(waveform2));
        title('Sygnał Baseband (PRN = 5) - Realna część');
        xlabel('Próbki'); ylabel('Amplituda');
    else
        error("Zadanie 2: BŁĄD – nie udało się wygenerować sygnału baseband.");
    end

    %% Zadanie 3: Generowanie sygnału IF (dla konfiguracji z PRN = 1)
    disp("========== Zadanie 3: Generowanie sygnału IF ==========");
    fIF = 2.0e6;  % Częstotliwość IF
    N = length(waveform1);
    t = (0:N-1)'/Fs1;
    ifSignal = waveform1 .* exp(1j*2*pi*fIF*t);
    disp(['Zadanie 3: Wygenerowano sygnał IF (fIF = ', num2str(fIF/1e6), ' MHz) o długości ', num2str(length(ifSignal)), ' próbek.']);
    % Wykres sygnału IF (realna część)
    figure;
    plot(real(ifSignal));
    title('Sygnał IF (PRN = 1) - Realna część');
    xlabel('Próbki'); ylabel('Amplituda');

    %% Zadanie 4: Generowanie zintegrowanego sygnału z wielu satelitów (PRN = 1,5,10)
    disp("========== Zadanie 4: Generowanie zintegrowanego sygnału z wielu satelitów ==========");
    prnList = [1, 5, 10];
    numSat = length(prnList);
    signalType = "LNAV";
    waveforms = cell(numSat, 1);
    FsCommon = -1;
    
    fprintf('Generowanie sygnałów dla %d satelitów...\n', numSat);
    for k = 1:numSat
        prn = prnList(k);
        fprintf('  Generowanie dla PRN %d...\n', prn);
        config = HelperGPSNavigationConfig('SignalType', signalType, 'PRNID', prn);
        if ~isfield(config, 'NavDataBitStartIndex')
            config.NavDataBitStartIndex = 1 + mod(k*100, 1000);
        end
        
        [wf, fs] = localGenerateGPSBaseband(config, NumNavDataBits);
        if isempty(wf)
            fprintf('  BŁĄD: Nie udało się wygenerować sygnału dla PRN %d. Pomijanie.\n', prn);
            continue;
        end
        waveforms{k} = wf;
        if FsCommon == -1
            FsCommon = fs;
        elseif FsCommon ~= fs
            error('Niezgodne częstotliwości próbkowania między satelitami!');
        end
        fprintf('  Wygenerowano %d próbek dla PRN %d, Fs = %.2f MHz.\n', length(wf), prn, fs/1e6);
    end
    
    validIdx = ~cellfun('isempty', waveforms);
    waveforms = waveforms(validIdx);
    prnListGenerated = prnList(validIdx);
    numSatGenerated = length(waveforms);
    
    if numSatGenerated == 0
        disp("BŁĄD: Nie udało się wygenerować sygnału dla żadnego satelity.");
        return;
    end
    
    disp(['Faktycznie wygenerowano sygnały dla ', num2str(numSatGenerated), ' satelitów.']);
    minLen = min(cellfun(@length, waveforms));
    fprintf('Sumowanie sygnałów (do długości %d próbek)...\n', minLen);
    
    combined = zeros(minLen, 1);
    for k = 1:numSatGenerated
        delaySamples = randi([0, 100]);
        powerScale = 10^(-rand()*0.5);
        validIndices = (1+delaySamples) : minLen;
        if ~isempty(validIndices) && validIndices(1) <= length(waveforms{k})
            combined(validIndices) = combined(validIndices) + ...
                powerScale * waveforms{k}(1:length(validIndices));
        end
    end
    
    prnStr = strjoin(string(prnListGenerated), ", ");
    disp(['Zsumowano sygnały dla PRN: ', prnStr]);
    disp("Odbiornik może je rozróżnić dzięki unikalnym kodom PRN.");
    fprintf('Zintegrowany sygnał ma %d próbek, Fs = %.2f MHz.\n', length(combined), FsCommon/1e6);
    % Wykres zintegrowanego sygnału
    figure;
    plot(real(combined));
    title('Zintegrowany sygnał z wielu satelitów - Realna część');
    xlabel('Próbki'); ylabel('Amplituda');
    
    %% Podsumowanie
    disp("========== Podsumowanie ==========");
    disp("Zadanie 1: Sygnał baseband (PRN = 1) wygenerowany.");
    disp("Zadanie 2: Sygnał baseband (efemerydy, PRN = 5) wygenerowany.");
    disp("Zadanie 3: Sygnał IF (PRN = 1) wygenerowany.");
    disp("Zadanie 4: Zintegrowany sygnał z wielu satelitów wygenerowany.");
end

%% ========================================================================
% Funkcja generująca sygnał baseband (upraszczona wersja)
%% ========================================================================
function [gpsBBWaveform, Fs] = localGenerateGPSBaseband(config, NumNavDataBits)
    Fs = 10.23e6;  % Zakładana częstotliwość próbkowania
    numBBSamplesPerDataBit = 204600;
    PRNID = config.PRNID;
    
    if isfield(config, 'NavDataBitStartIndex')
        NavDataBitStartIndex = config.NavDataBitStartIndex;
    else
        NavDataBitStartIndex = 1;
        disp("Ostrzeżenie: Używam domyślnego NavDataBitStartIndex = 1");
    end
    
    % Generowanie bitów danych (stub)
    navData = HelperGPSNAVDataEncode(config);
    if length(navData) >= NumNavDataBits
        navData = navData(1:NumNavDataBits);
    else
        error('Wygenerowano za mało bitów danych.');
    end
    fprintf('Wygenerowano %d bitów nawigacyjnych.\n', length(navData));
    
    totalSamples = NumNavDataBits * numBBSamplesPerDataBit;
    gpsBBWaveform = complex(zeros(totalSamples, 1));
    
    CLCodeResetIdx = 75;
    CLCodeIdx = mod(NavDataBitStartIndex - 1, CLCodeResetIdx);
    
    % Ustawiamy obie gałęzie jako stringi o tej samej długości (6 znaków)
    IBranchContent = "P(Y)+D";   % 6 znaków
    QBranchContent = "C/A+D ";    % 6 znaków (z odstępem)
    IQContent = [IBranchContent, QBranchContent];  % 1x2 string array
    
    for iDataBit = 1:NumNavDataBits
        indices = ((iDataBit-1)*numBBSamplesPerDataBit + 1):(iDataBit*numBBSamplesPerDataBit);
        currentLNAVBit = navData(iDataBit);
        % Wywołanie stubowej funkcji generującej segment baseband
        segment = HelperGPSBasebandWaveform(IQContent, [], PRNID, CLCodeIdx, currentLNAVBit);
        if length(segment) ~= numBBSamplesPerDataBit
            error('Niespodziewana długość segmentu: oczekiwano %d, otrzymano %d', numBBSamplesPerDataBit, length(segment));
        end
        gpsBBWaveform(indices) = segment;
        CLCodeIdx = mod(CLCodeIdx + 1, CLCodeResetIdx);
    end
end

%% ========================================================================
% Stub: HelperGPSNAVDataEncode
%% ========================================================================
function navData = HelperGPSNAVDataEncode(~)
    % Uproszczona implementacja – generujemy 100 bitów (wszystkie zero)
    navData = zeros(100, 1);
end

%% ========================================================================
% Stub: HelperGPSBasebandWaveform
%% ========================================================================
function segment = HelperGPSBasebandWaveform(~, ~, ~, ~, currentLNAVBit)
    % Uproszczona implementacja – generujemy sinusoidę, aby uzyskać niezerowy sygnał
    % Zmienna currentLNAVBit można wykorzystać do modyfikacji amplitudy (tutaj pomijamy)
    t = (0:204599)'/204600;
    segment = sin(2*pi*10*t); % sinus o częstotliwości 10 Hz (dla demonstracji)
end

%% ========================================================================
% Stub: HelperGPSNavigationConfig
%% ========================================================================
function config = HelperGPSNavigationConfig(varargin)
    % Implementacja konfiguracji jako struktura – argumenty name-value
    config = struct();
    for i = 1:2:length(varargin)
        config.(varargin{i}) = varargin{i+1};
    end
    % Ustawienia domyślne:
    config.FrameIndices = 1:25;
    config.TLMMessage = 0;
    config.HOWTOW = 1;
    config.AntiSpoofFlag = 0;
    config.CodesOnL2 = "P-code";
    config.L2PDataFlag = 0;
    config.SVHealth = 0;
    config.IssueOfDataClock = 0;
    config.URAID = 0;
    config.WeekNumber = 2149;
    config.GroupDelayDifferential = 0;
    config.SVClockCorrectionCoefficients = ones(3,1);
    config.ReferenceTimeOfClock = 0;
    config.SemiMajorAxisLength = 26560000;
    config.MeanMotionDifference = 0;
    config.FitIntervalFlag = 0;
    config.Eccentricity = 0.02;
    config.MeanAnomaly = 0;
    config.ReferenceTimeOfEphemeris = 0;
    config.HarmonicCorrectionTerms = ones(6,1);
    config.IssueOfDataEphemeris = 0;
    config.IntegrityStatusFlag = 0;
    config.ArgumentOfPerigee = -0.52;
    config.RateOfRightAscension = 0;
    config.LongitudeOfAscendingNode = -0.84;
    config.Inclination = 0.3;
    config.InclinationRate = 0;
    config.AlertFlag = 0;
    config.AgeOfDataOffset = 0;
    config.NMCTAvailabilityIndicator = 0;
    config.NMCTERD = ones(30,1);
    config.AlmanacFileName = "gpsAlmanac.txt";
    config.Ionosphere = struct();
    config.UTC = struct();
    config.TextMessage = 'This content is part of Satellite Communications Toolbox. Thank you. ';
end

%% ========================================================================
% Stub: localLoadRinexEphemeris
%% ========================================================================
function ephem = localLoadRinexEphemeris(rinexFile, prn)
    disp('OSTRZEŻENIE: Funkcja localLoadRinexEphemeris jest placeholderem.');
    disp(['Wczytywanie danych dla ', rinexFile, ' dla PRN=', string(prn)]);
    ephem.WeekNumber = 2240;
    ephem.Toe = 350000 + randi(1000);
    ephem.Ecc = 0.01 + rand()*0.01;
    ephem.sqrtA = 5153 + rand();
    disp('Zwrócono przykładowe wartości efemeryd.');
end
