function Lab6()
NumNavDataBits = 5;

disp("========== Zadanie 1: Konfiguracja i sygnał baseband (PRN = 1) ==========");
config1 = HelperGPSNavigationConfig('SignalType',"LNAV",'PRNID',1);
disp(config1);
config1.WeekNumber = 2240;
config1.Eccentricity = 0.03;
config1.ReferenceTimeOfEphemeris = 360000;
if ~isfield(config1, 'NavDataBitStartIndex')
    config1.NavDataBitStartIndex = 1;
    disp("Ostrzeżenie: Używam domyślnego NavDataBitStartIndex = 1")
end
disp(config1);
[waveform1, Fs1] = generateBasebandSignal(config1, NumNavDataBits);
disp(['Zadanie 1: Wygenerowano sygnał baseband (PRN = 1) z ', num2str(length(waveform1)), ' próbek, Fs = ', num2str(Fs1/1e6), ' MHz.']);
figure; plot(real(waveform1(1:2000))); title('Sygnał Baseband (PRN = 1)'); xlabel('Próbki'); ylabel('Amplituda'); grid on; ylim([-1.5 1.5]);
figure; pwelch(waveform1, [], [], [], Fs1, 'centered'); title('PSD Sygnału Baseband (PRN = 1)');
if length(waveform1)>=10230
    segment_for_corr = waveform1(1:10230);
    [corr_vals, lags] = xcorr(segment_for_corr, segment_for_corr);
    figure; plot(lags/10, abs(corr_vals)/max(abs(corr_vals))); title('Normalizowana Autokorelacja kodu C/A (PRN = 1)'); xlabel('Przesunięcie [chipy C/A]'); ylabel('Amplituda korelacji (znormalizowana)'); grid on; xlim([-50 50]);
else
    disp('Ostrzeżenie: Sygnał za krótki do autokorelacji.')
end

disp("========== Zadanie 2: Dane efemeryd i sygnał baseband (PRN = 5) ==========");
rinexFile = "brdc1230.22n"; prn2 = 5;
ephem = localLoadRinexEphemeris(rinexFile, prn2);
config2 = HelperGPSNavigationConfig('SignalType',"LNAV",'PRNID',prn2);
disp(['Oryginalny WeekNumber dla PRN = ', num2str(prn2), ': ', num2str(config2.WeekNumber)]);
disp(['Oryginalny ReferenceTimeOfEphemeris dla PRN = ', num2str(prn2), ': ', num2str(config2.ReferenceTimeOfEphemeris)]);
config2.WeekNumber = ephem.WeekNumber;
config2.ReferenceTimeOfEphemeris = ephem.Toe;
config2.Eccentricity = ephem.Ecc;
if ~isfield(config2, 'NavDataBitStartIndex')
    config2.NavDataBitStartIndex = 1;
    disp("Ostrzeżenie: Używam domyślnego NavDataBitStartIndex = 1")
end
disp(config2);
[waveform2, Fs2] = generateBasebandSignal(config2, NumNavDataBits);
disp(['Zadanie 2: Wygenerowano sygnał baseband (PRN = 5) z ', num2str(length(waveform2)), ' próbek, Fs = ', num2str(Fs2/1e6), ' MHz.']);
figure; plot(real(waveform2(1:2000))); title('Sygnał Baseband (PRN = 5)'); xlabel('Próbki'); ylabel('Amplituda'); grid on; ylim([-1.5 1.5]);
figure; pwelch(waveform2, [], [], [], Fs2, 'centered'); title('PSD Sygnału Baseband (PRN = 5)');

disp("========== Zadanie 3: Generowanie sygnału IF ==========");
fIF = 2.0e6; N = length(waveform1); t = (0:N-1)'/Fs1;
ifSignal = waveform1 .* exp(1j*2*pi*fIF*t);
disp(['Zadanie 3: Wygenerowano sygnał IF (fIF = ', num2str(fIF/1e6), ' MHz) o długości ', num2str(length(ifSignal)), ' próbek.']);
figure; plot(1:2000, real(ifSignal(1:2000)), 1:2000, imag(ifSignal(1:2000)), '--'); title('Sygnał IF (PRN = 1)'); xlabel('Próbki'); ylabel('Amplituda'); legend('Real','Imag'); grid on;
figure; pwelch(ifSignal, [], [], [], Fs1, 'centered'); title(['PSD Sygnału IF (PRN = 1), fIF = ', num2str(fIF/1e6), ' MHz']);

disp("========== Zadanie 4: Generowanie zintegrowanego sygnału z wielu satelitów ==========");
prnList = [1, 5, 10]; numSat = length(prnList); signalType = "LNAV"; waveforms = cell(numSat,1); FsCommon = -1;
fprintf('Generowanie sygnałów dla %d satelitów...\n', numSat);
for k = 1:numSat
    prn = prnList(k);
    fprintf('  Generowanie dla PRN %d...\n', prn);
    cfg = HelperGPSNavigationConfig('SignalType',signalType,'PRNID',prn);
    if ~isfield(cfg, 'NavDataBitStartIndex')
        cfg.NavDataBitStartIndex = 1 + mod(k*100, 1000);
    end
    [wf, fs] = generateBasebandSignal(cfg, NumNavDataBits);
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
    delaySamples = randi([0,100]);
    powerScale = 10^(-rand()*0.5);
    validIndices = (1+delaySamples):minLen;
    if ~isempty(validIndices) && validIndices(1) <= length(waveforms{k})
        combined(validIndices) = combined(validIndices) + powerScale * waveforms{k}(1:length(validIndices));
    end
end
prnStr = strjoin(string(prnListGenerated), ", ");
disp(['Zsumowano sygnały dla PRN: ', prnStr]);
disp("Odbiornik może je rozróżnić dzięki unikalnym kodom PRN.");
fprintf('Zintegrowany sygnał ma %d próbek, Fs = %.2f MHz.\n', length(combined), FsCommon/1e6);
figure; plot(real(combined(1:2000))); title('Zintegrowany sygnał - Fragment'); xlabel('Próbki'); ylabel('Amplituda'); grid on;
figure; pwelch(combined, [], [], [], FsCommon, 'centered'); title(['PSD Zintegrowanego Sygnału (PRN: ', prnStr, ')']);

disp("========== Podsumowanie ==========");
disp("Zadanie 1: Sygnał baseband (PRN = 1) wygenerowany.");
disp("Zadanie 2: Sygnał baseband (efemerydy, PRN = 5) wygenerowany.");
disp("Zadanie 3: Sygnał IF (PRN = 1) wygenerowany.");
disp("Zadanie 4: Zintegrowany sygnał z wielu satelitów wygenerowany.");
end

function [baseband, Fs] = generateBasebandSignal(config, numBits)
Fs = 10.23e6;
numBBSamplesPerDataBit = 204600;
PRNID = config.PRNID;
if isfield(config, 'NavDataBitStartIndex')
    NavDataBitStartIndex = config.NavDataBitStartIndex;
else
    NavDataBitStartIndex = 1;
    disp("Ostrzeżenie: Używam domyślnego NavDataBitStartIndex = 1")
end
navData = generateNavData(numBits);
fprintf('Wygenerowano %d bitów nawigacyjnych.\n', length(navData));
totalSamples = numBits * numBBSamplesPerDataBit;
baseband = complex(zeros(totalSamples, 1));
CLCodeResetIdx = 75;
CLCodeIdx = mod(NavDataBitStartIndex - 1, CLCodeResetIdx);
ca = generateCAcode(PRNID);
ca_os = repelem(ca, 10);
period = ca_os;
periodRep = repmat(period, 20, 1);
idxStart = 1;
for i = 1:numBits
    idxEnd = i * numBBSamplesPerDataBit;
    baseband(idxStart:idxEnd) = navData(i) * periodRep;
    idxStart = idxEnd + 1;
    CLCodeIdx = mod(CLCodeIdx + 1, CLCodeResetIdx);
end
end

function bits = generateNavData(numBits)
bits = randi([0,1], numBits, 1);
bits = bits * 2 - 1;
end

function ca = generateCAcode(prn)
N = 1023;
g1 = ones(1,10);
g2 = ones(1,10);
ca = zeros(1,N);
tapTable = [2,6; 3,7; 4,8; 5,9; 1,9; 2,10; 1,8; 2,9; 3,10; 2,3; 3,4; 5,6; 6,7; 7,8; 8,9; 9,10; 1,4; 2,5; 3,6; 4,7; 5,8; 6,9; 1,3; 4,6; 5,7; 6,8; 7,9; 8,10; 1,6; 2,7; 3,8; 4,9];
taps = tapTable(prn,:);
for i = 1:N
    g1_out = g1(10);
    g2_out = xor(g2(taps(1)), g2(taps(2)));
    ca(i) = mod(g1_out + g2_out,2);
    new_bit1 = mod(g1(3) + g1(10),2);
    g1 = [new_bit1, g1(1:9)];
    new_bit2 = mod(g2(2)+g2(3)+g2(6)+g2(8)+g2(9)+g2(10),2);
    g2 = [new_bit2, g2(1:9)];
end
ca = ca * 2 - 1;
end

function out = repelem(in, factor)
out = reshape(repmat(in, factor, 1), [], 1);
end

function ephem = localLoadRinexEphemeris(rinexFile, prn)
disp('OSTRZEŻENIE: Funkcja localLoadRinexEphemeris jest placeholderem.');
disp(['Wczytywanie danych dla ', rinexFile, ' dla PRN=', string(prn)]);
ephem.WeekNumber = 2240;
ephem.Toe = 350000 + randi(1000);
ephem.Ecc = 0.01 + rand()*0.01;
ephem.sqrtA = 5153 + rand();
disp('Zwrócono przykładowe wartości efemeryd.');
end

function config = HelperGPSNavigationConfig(varargin)
config = struct();
for i = 1:2:length(varargin)
    config.(varargin{i}) = varargin{i+1};
end
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
end

% =========================================================================
% Odpowiedzi Teoretyczne
% =========================================================================
%
% 1. Obiekt Konfiguracyjny GPS:
%    - Obiekt konfiguracyjny to struktura (lub klasa), która zawiera wszystkie 
%      parametry niezbędne do generacji sygnału GPS, takie jak typ sygnału 
%      (LNAV, CNAV), PRN (numer satelity), parametry orbitalne, ustawienia zegara, 
%      kody rozpraszające i inne.
%
%    - Przykładowe właściwości: 
%         WeekNumber, Eccentricity, ReferenceTimeOfEphemeris, FrameIndices, 
%         TLMMessage, HOWTOW, CodesOnL2, L2PDataFlag, SVHealth, itd.
%
%    -  Umożliwia łatwe modyfikowanie i centralne zarządzanie parametrami, 
%         standaryzację konfiguracji w symulacji, oraz integrację różnych modułów
%         (np. generacji kodów, modulacji, enkodowania danych). Dzięki temu zmiany w 
%         konfiguracji szybko przekładają się na zmianę wygenerowanego sygnału, co 
%         ułatwia testowanie i optymalizację algorytmów.
%
% 2. Parametry Efemeryd i Almanach:
%    - Efemerydy dostarczają szczegółowe informacje o orbicie satelity, takie jak 
%      długość półosi wielkiej, ekscentryczność, inklinacja, argument perygeum, 
%      a także informacje zegarowe. Plik almanachu zawiera uproszczone dane o 
%      pozycjach satelitów.
%
%    -    Numer tygodnia określony w pliku almanachu musi być zgodny z tym w 
%         obiekcie konfiguracyjnym, aby zapewnić poprawną synchronizację zegarową 
%         oraz dokładne obliczenia pozycji.
%
%    - Informacje: 
%         Efemerydy zawierają dane orbitalne (np. semi-major axis, ekscentryczność, 
%         inklinację), podczas gdy almanach daje ogólny obraz pozycji satelitów, co 
%         umożliwia szybką akwizycję sygnału.
%
% 3. Generowanie Sygnału Pasma Podstawowego i IF:
%    - Sygnał pasma podstawowego (baseband) to sygnał generowany na poziomie danych 
%      nawigacyjnych, który zawiera kody rozpraszające (np. C/A) i dane LNAV.
%
%    - Sygnał IF (Intermediate Frequency) jest wynikiem przesunięcia częstotliwości 
%      sygnału baseband przez mnożenie przez exp(j*2π*fIF*t), co przesuwa widmo 
%      sygnału do wyższej częstotliwości.
%
%    - Gałęzie I i Q (in-phase i quadrature) umożliwiają pełną reprezentację sygnału 
%      zespolonego, co jest kluczowe dla modulacji i demodulacji sygnału w systemach RF.
%
% 4. Generowanie Sygnału z Wielu Satelitów:
%    - Kody PRN to unikalne kody rozpraszające przypisane do poszczególnych satelitów, 
%      umożliwiające rozróżnienie sygnałów nadawanych na tej samej częstotliwości.
%
%    - Sygnał GPS odbierany przez odbiornik to suma sygnałów z wielu satelitów. Dzięki 
%      unikalnym kodom PRN, odbiornik poprzez dekorelację może wydobyć sygnał konkretnego 
%      satelity.
%
%    -    Integracja sygnałów pozwala na symulację rzeczywistych warunków, gdzie 
%         odbiornik musi rozróżniać sygnały z wielu satelitów, co jest podstawą metody 
%         CDMA wykorzystywanej w GPS.
%
% Odpowiedzi na Zadania Praktyczne:
%    1. Modyfikacja Obiektu Konfiguracyjnego:
%         - Zmiany parametrów, takich jak WeekNumber, ReferenceTimeOfEphemeris, wpływają 
%           na generowane dane nawigacyjne i kody, co w pełnej implementacji przekłada się na 
%           zmianę pozycji satelitów i synchronizację zegara.
%
%    2. Użycie Rzeczywistych Danych Efemeryd:
%         - Wprowadzenie rzeczywistych danych orbitalnych (efemeryd) powoduje, że 
%           wygenerowany sygnał jest bliższy warunkom rzeczywistym, co jest kluczowe przy 
%           obliczaniu pozycji.
%
%    3. Generowanie Sygnału IF:
%         - Mnożenie sygnału baseband przez exp(j*2πfIF*t) przesuwa widmo do częstotliwości 
%           IF, co jest kluczowe w systemach RF i umożliwia wykorzystanie właściwych filtrów.
%
%    4. Generowanie Zintegrowanego Sygnału z Wielu Satelitów:
%         - Sumowanie sygnałów z różnych satelitów przy użyciu unikalnych kodów PRN pozwala 
%           symulować warunki odbioru, gdzie sygnały nakładają się, ale dzięki korelacji odbiornik 
%           może je rozróżnić.
%
%
% =========================================================================

