% This function reads the .lmv file from Labview and does an FFT on the
% logged voltage values from the transducer. The results are shown in
% graphical form. This function also shows the effect of a Butterworth
% filter on the signal.
% The input .lmv file is organised according to the following format:
% i. Time (s) and Voltage (V)
% The sampling frequency and test time are stored in the Excel file
% describing the tests.
% TO DO:
% 1. Import .lmv file removing the file and column headers. DONE.
% 2. Plot voltage against time. DONE.
% 3. Calculate the power spectral density. DONE.
% 4. Graph the power spectral density. DONE.
% 5. Filter design. 
% REMINDER: This function uses the lvm_import.m function. Both functions
% must be placed in the same workspace for this function to work.

%{
All variables needed to process the raw data files are defined in this section.
%}
clc;
clear;
samplingFrequency = 10000;
samplingTime = 1/ samplingFrequency;
lengthOfSignal = 10;
numberOfSamples = lengthOfSignal / samplingTime;
cutOffFrequency = 50;
filterOrder = 1;


%{
Raw data is imported to matrixes and vectors in this section.
%}
[fileName, pathName, filterIndex] = uigetfile({'*.lvm'}, 'Load Labview File', '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Torque transducer voltages/');
if isequal(fileName, 0)
    disp('User selected Cancel');
else
    filePath = strcat(pathName, fileName);
    importedDataFrame = lvm_import(filePath, 1);
    rawVoltageData = importedDataFrame.Segment1.data;
    %{
        Voltage against time plot is done in this section.
    %}
    figure(1);
    clf;
    hold on;
    plot(rawVoltageData(:,1), rawVoltageData(:, 2));
    title('Transducer output voltage');
    ylabel('Voltage (V)');
    xlabel('Time (s)');

    %{
        FFT on the signal is done in this section.
    %}
    amplitudeVector = fft(rawVoltageData(:, 2));
    amplitudeVector(1) = [];
    n = length(amplitudeVector);
    powerVector = abs(amplitudeVector(1:floor(n/2))).^2;
    nyquistFrequency = samplingFrequency / 2;
    frequencyVector = (1:n/2)/ (n/2) * nyquistFrequency;

    %{
        Power spectral density graph is done in this section.
    %}
    figure(2);
    clf;
    hold on;
    plot(frequencyVector, powerVector);
    maxFrequencyIndex = find(powerVector == max(powerVector));
    mainPeriodStr = num2str(frequencyVector(maxFrequencyIndex));
    plot(frequencyVector(maxFrequencyIndex), powerVector(maxFrequencyIndex), 'r.', 'MarkerSize', 25);
    text(frequencyVector(maxFrequencyIndex) + 2, powerVector(maxFrequencyIndex), ['Frequency = ', mainPeriodStr]);
    title('Fast Fourier transform');
    ylabel('Amplitude');
    xlabel('Frequency (Hz)');

    %{
        Filter design is done in this section.
    %}
    [numeratorTranferFunction, denominatorTransferFunction] = butter(filterOrder, 2 * pi * cutOffFrequency, 'low', 's');
    Hsys = tf(numeratorTranferFunction, denominatorTransferFunction);
    filteredVoltageData = lsim(Hsys, rawVoltageData(:, 2), rawVoltageData(:, 1));
    figure(3);
    clf;
    hold on;
    plot(rawVoltageData(:, 1), filteredVoltageData(:, 1));
    title('Filtered transducer output voltage');
    ylabel('Voltage (V)');
    xlabel('Time (s)');
end




