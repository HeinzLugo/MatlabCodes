% This function reads the .csv file from the Garmin powermeter and determines
% the average value and standard deviation for the speed, heart rate, cadence
% and power variables. Data is organized by kilometer and also by time. The
% results are stored on a table. 
% The input csv. files are organised according to the following formats:
% 1. Garmin file: i. Time (Unix time), ii. Distance (km), iii. Heart rate, iv. Cadence (rpm)
%                 and v. Power (Watts).
% 2. RPE file: i. Time (min) and ii. RPE.
% REMINDER FOR RAW FILE PREPROCESSING:
% The original Garmin file must be preprocessed to prevent issues during
% the csvread function call. 
% The modifications needed are: i. Replace the
% TIME column values with the UNIX TIME column values. ii. Remove the UNIX
% TIME, LAT, LONG, ALT and TEMP columns. iii. The first row of the file
% must have a distance close to 0 but larger than 0 (e.g. 0.003). If there
% are rows prior to such value remove them from the file. iv. Replace all
% instances of No Data to a value of 0. v. Although not essential remove
% the rows above the test distance (i.e. 4km) for the test file not the
% warmup files.
% POSSIBLE ISSUES ON THE DATA:
% 1. Data from the Garmin file can be repeated. This means that data from
% for example 1.1 km to 1.3 km can be present twice on the file. Occurence
% can be detected by graphing the distance value. Remove the repeated
% values.
% 2. Power values can be extremely high (e.g. 2000W) within a very small
% time window (e.g. 1s). Occurence can be detected by graphing the power
% values. Unrealistic values should be replaced by linear interpolation
% between the previous and the next power values.
% 3. Same issues as with the power can occur for the cadence values.
% Unrealistic values should be replaced by linear interpolation between the
% previous and the next cadence values.
% 4. Although not encountered yet data should be checked for negative
% values. If such cases occur replace the values by linear interpolation
% between the previous and the next value.
% 5. If cadence or power values have consecutive values of 0 and linear
% interpolation is not possibly do not modify the values.
% IMPORTANT FILE NAMING CONVENTION:
% All raw files (i.e. Garmin and RPE) must be named using the test subjects
% name and forename capitalised initials as the first two characters on the
% file name. (e.g. HLfeedbackRPE, HLfeedback200814).
% CAUTION:
% 1. File paths are set to my home folder change accordingly to other
% machines as required. Athough the file location is not relevant there
% should be 3 folders, one named Test, one name Warmup and another named
% RPEF or RPENF for the feedback and no feedback cases respectively.
% 2. If you want to change the file paths you must change the following
% variables:
%   - filePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02
%   Bike project/03 Test Data/Feedback tests/Import Files/Feedback';
%   - filePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02
%   Bike project/03 Test Data/Feedback tests/Import Files/No Feedback';
%   - filePath = strcat(filePath, '/Test/');
%   - filePath = strcat(filePath, '/Warmup/');
%   - rpeFilePath = strcat('/Users/heinzlugo/Documents/01 Postgraduate
%   project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback/RPEF/', strcat(fileName(1:2), 'feedbackRPE.csv'));
%   - rpeFilePath = strcat('/Users/heinzlugo/Documents/01 Postgraduate
%   project/02 Bike project/03 Test Data/Feedback tests/Import Files/No
%   feedback/RPENF/', strcat(fileName(1:2), 'NofeedbackRPE.csv'));
%   -  outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate
%   project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback summary/Test/'; 
%   -  outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate
%   project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback summary/Warmup/';
%   - outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/No feedback summary/Test/'; 
%   - outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate
%   project/02 Bike project/03 Test Data/Feedback tests/Import Files/No feedback summary/Warmup/'; 
% TO DO:
% 1. Check that the time per kilometer is correct. DONE
% 2. Check that the average and standard deviation values are correct. DONE
% 3. Change the time to minutes on the resultByTime. DONE
% 4. Check the distance per minute on the resultByTime. DONE
% 5. Add the RPE information to the time table. If not on the time table
% integrate with the table. NOT DONE
% 6. Check that all available options work. DONE
% 7. Add on the preformat required to remove all negative values or power
% values above 1600W. DONE
% 8. Validation of matlab logic for test files. DONE
% 9. Validation of matalab logic for warmup files. DONE
% 10. Graphs logic. NOT DONE

%{
All variables needed to process the raw data files (e.g. column indexes) are defined in this section.
If graphs are required n change the graphsRequired boolean variable value to true. If the analysis is
to be done on a warmup file change the testFile boolean variable value to false.
%}
clc;
clear;
graphsRequired = false;
indexRowGarmin = 1;
indexRowRPE = 1;
indexTimeGarmin = 1;
indexDistance = 2;
indexHeartRate = 3;
indexCadence = 4;
indexPower = 5;
indexTimeRPE = 1;
indexRPE = 2;
timeTrialDistance = 4;
indexColumnGarminFormatted = 6;
indexTimeGarminFormatted = 1;
indexDistanceGarminFormatted = 2;
indexSpeedGarminFormatted = 3;
indexHeartRateGarminFormatted = 4;
indexCadenceGarminFormatted = 5;
indexPowerGarminFormatted = 6;
samplingRateGarmin = 1;
secondsToHourFactor = 3600;
secondsToMinuteFactor = 60;
indexColumnResultByDistance = 10;
indexColumnResultByTime = 10;
indexResultDistance = 1;
indexResultTime = 1;
indexResultTimePerKM = 2;
indexResultDistancePerMinute = 2;
indexResultSpeedAverage = 3;
indexResultSpeedStdDeviation = 4;
indexResultHRAverage = 5;
indexResultHRStdDeviation = 6;
indexResultCadenceAverage = 7;
indexResultCadenceStdDeviation = 8;
indexResultPowerAverage = 9;
indexResultPowerStdDeviation = 10;

%{
Raw data is imported to Matlab matrixes in this section.
%}
testTypeSelection = menu('Choose the test type', 'Feedback', 'No feedback');

switch testTypeSelection
    case 1
        filePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback';
    case 2
        filePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/No Feedback';
end

if testTypeSelection ~= 0
    fileTypeSelection = menu('Choose the file type', 'Test file', 'Warmup file');
    switch fileTypeSelection
        case 1
            filePath = strcat(filePath, '/Test/');
        case 2
            filePath = strcat(filePath, '/Warmup/');
        otherwise
            disp('By default test file is choosen');
            filePath = strcat(filePath, '/Test/');
    end
    
    [fileName, pathName, filterIndex] = uigetfile({'*.csv'}, 'Choose the file to be analysed', filePath);
    
    if isequal(fileName,0)
        disp('User selected Cancel');
    else
        garminFilePath = strcat(pathName, fileName);
        if fileTypeSelection == 1
            if testTypeSelection == 1
                rpeFilePath = strcat('/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback/RPEF/', strcat(fileName(1:2), 'feedbackRPE.csv'));                    
            else
                rpeFilePath = strcat('/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/No feedback/RPENF/', strcat(fileName(1:2), 'NofeedbackRPE.csv'));
            end
            dataGarmin = csvread(garminFilePath, indexRowGarmin, 0);
            dataRPE = csvread(rpeFilePath, indexRowRPE, 0);
        else
            dataGarmin = csvread(garminFilePath, indexRowGarmin, 0);
        end
        
        %{
        Data is formatted in this section.
        %}
        if fileTypeSelection == 1
            if dataGarmin(size(dataGarmin, 1), indexDistance) < timeTrialDistance
                indexRowDataGarminFormatted = size(dataGarmin, 1);
            else
                for i = 1:size(dataGarmin,1)
                    if dataGarmin(i, indexDistance) == timeTrialDistance
                        indexRowDataGarminFormatted = i;
                        break;
                    elseif dataGarmin(i, indexDistance) > timeTrialDistance
                        indexRowDataGarminFormatted = i - 1;
                        break;
                    end
                end
            end
        else
            indexRowDataGarminFormatted = size(dataGarmin, 1);
        end

        dataGarminFormatted = zeros(indexRowDataGarminFormatted, indexColumnGarminFormatted);

        for i = 1:indexRowDataGarminFormatted
            dataGarminFormatted(i, indexTimeGarminFormatted) = i;
            if i == 1
                dataGarminFormatted(i, indexSpeedGarminFormatted) = (dataGarmin(i, indexDistance) / samplingRateGarmin) * secondsToHourFactor;
            else
                dataGarminFormatted(i, indexSpeedGarminFormatted) = ((dataGarmin(i, indexDistance) - dataGarmin(i - 1, indexDistance))/ samplingRateGarmin) * secondsToHourFactor;
            end
        end

        dataGarminFormatted(1:indexRowDataGarminFormatted, indexDistanceGarminFormatted) = dataGarmin(1:indexRowDataGarminFormatted, indexDistance);
        dataGarminFormatted(1:indexRowDataGarminFormatted, indexHeartRateGarminFormatted:indexPowerGarminFormatted) = dataGarmin(1:indexRowDataGarminFormatted, indexHeartRate:indexPower);
        
        %{
        Average and standard deviation values for each of the variables (e.g. power, cadence) are calculated in this section by time and distance.
        %}
        if fileTypeSelection == 1
            resultDataByDistance = zeros(timeTrialDistance, indexColumnResultByDistance);
        else
            resultDataByDistance = zeros(ceil(dataGarminFormatted(indexRowDataGarminFormatted, indexDistanceGarminFormatted)), indexColumnResultByDistance);
        end

        resultDataByTime = zeros(ceil(dataGarminFormatted(size(dataGarminFormatted, 1), indexTimeGarminFormatted) / secondsToMinuteFactor), indexColumnResultByTime);

        for i = 1:size(resultDataByDistance, 1)
            if i == 1
                dataOrganisedByDistance = dataGarminFormatted(dataGarminFormatted(:, indexDistanceGarminFormatted) <= i, :);
            else
                dataOrganisedByDistance = dataGarminFormatted(and((i - 1) < dataGarminFormatted(:, indexDistanceGarminFormatted), dataGarminFormatted(:, indexDistanceGarminFormatted) <= i), :);
            end
            resultDataByDistance(i, indexResultDistance) = i;
            if i == 1
                resultDataByDistance(i, indexResultTimePerKM) = dataOrganisedByDistance(size(dataOrganisedByDistance, 1), indexTimeGarminFormatted) / secondsToMinuteFactor;
            else
                resultDataByDistance(i, indexResultTimePerKM) = (dataOrganisedByDistance(size(dataOrganisedByDistance, 1), indexTimeGarminFormatted) / secondsToMinuteFactor) - sum(resultDataByDistance(1:i-1, indexResultTimePerKM));
            end
            resultDataByDistance(i, indexResultSpeedAverage) = mean(dataOrganisedByDistance(:, indexSpeedGarminFormatted));
            resultDataByDistance(i, indexResultSpeedStdDeviation) = std(dataOrganisedByDistance(:, indexSpeedGarminFormatted));
            resultDataByDistance(i, indexResultHRAverage) = mean(dataOrganisedByDistance(:, indexHeartRateGarminFormatted));
            resultDataByDistance(i, indexResultHRStdDeviation) = std(dataOrganisedByDistance(:, indexHeartRateGarminFormatted));
            resultDataByDistance(i, indexResultCadenceAverage) = mean(dataOrganisedByDistance(:, indexCadenceGarminFormatted));
            resultDataByDistance(i, indexResultCadenceStdDeviation) = std(dataOrganisedByDistance(:, indexCadenceGarminFormatted));
            resultDataByDistance(i, indexResultPowerAverage) = mean(dataOrganisedByDistance(:, indexPowerGarminFormatted));
            resultDataByDistance(i, indexResultPowerStdDeviation) = std(dataOrganisedByDistance(:, indexPowerGarminFormatted));
            dataOrganisedByDistance = [];
        end

        for i = 1:size(resultDataByTime, 1)
            if i == 1
                dataOrganisedByTime = dataGarminFormatted(dataGarminFormatted(:, indexTimeGarminFormatted) <= i * secondsToMinuteFactor, :);
            else
                dataOrganisedByTime = dataGarminFormatted(and((i - 1) * secondsToMinuteFactor < dataGarminFormatted(:, indexTimeGarminFormatted), dataGarminFormatted(:, indexTimeGarminFormatted) <= i * secondsToMinuteFactor) , :);
            end
            resultDataByTime(i, indexResultTime) = i;
            if i == 1
                resultDataByTime(i, indexResultDistancePerMinute) = dataOrganisedByTime(size(dataOrganisedByTime, 1), indexDistanceGarminFormatted);
            else
                resultDataByTime(i, indexResultDistancePerMinute) = (dataOrganisedByTime(size(dataOrganisedByTime, 1), indexDistanceGarminFormatted)) - sum(resultDataByTime(1:i-1, indexResultDistancePerMinute));
            end
            resultDataByTime(i, indexResultSpeedAverage) = mean(dataOrganisedByTime(:, indexSpeedGarminFormatted));
            resultDataByTime(i, indexResultSpeedStdDeviation) = std(dataOrganisedByTime(:, indexSpeedGarminFormatted));
            resultDataByTime(i, indexResultHRAverage) = mean(dataOrganisedByTime(:, indexHeartRateGarminFormatted));
            resultDataByTime(i, indexResultHRStdDeviation) = std(dataOrganisedByTime(:, indexHeartRateGarminFormatted));
            resultDataByTime(i, indexResultCadenceAverage) = mean(dataOrganisedByTime(:, indexCadenceGarminFormatted));
            resultDataByTime(i, indexResultCadenceStdDeviation) = std(dataOrganisedByTime(:, indexCadenceGarminFormatted));
            resultDataByTime(i, indexResultPowerAverage) = mean(dataOrganisedByTime(:, indexPowerGarminFormatted));
            resultDataByTime(i, indexResultPowerStdDeviation) = std(dataOrganisedByTime(:, indexPowerGarminFormatted));
            dataOrganisedByTime = [];
        end
        
        %{
        Result tables are constructed and stored in this section. 
        %}
        switch testTypeSelection
            case 1
                switch fileTypeSelection
                    case 1
                        outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback summary/Test/'; 
                    case 2
                        outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/Feedback summary/Warmup/';
                end
            case 2
                switch fileTypeSelection
                    case 1
                        outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/No feedback summary/Test/'; 
                    case 2
                        outputSummaryFilePath = '/Users/heinzlugo/Documents/01 Postgraduate project/02 Bike project/03 Test Data/Feedback tests/Import Files/No feedback summary/Warmup/'; 
                end
        end
        outputSummaryDataByDistanceFileName = strcat('SumByDist', fileName);
        outputSummaryDataByTimeFileName = strcat('SumByTime', fileName);
        summaryDataByDistanceFile = strcat(outputSummaryFilePath, outputSummaryDataByDistanceFileName);
        summaryDataByTimeFile = strcat(outputSummaryFilePath, outputSummaryDataByTimeFileName);
        % Data by distance
        resultDataByDistance_ColumnHeaders = ('Distance (Km), Time per Km (min), Speed average (Km/h), Speed standard deviation (Km/h), Heart rate average (BPM), Heart rate standard deviation (BPM), Cadence average (rpm), Cadence standard deviation (rpm), Power average (Watts), Power standard deviation (Watts)');
        resultDataByDistance_File = fopen(summaryDataByDistanceFile, 'w+');
        fprintf(resultDataByDistance_File, '%s', resultDataByDistance_ColumnHeaders);
        fclose(resultDataByDistance_File);
        dlmwrite(summaryDataByDistanceFile, resultDataByDistance, 'roffset', 1, '-append');
        % Data by time
        resultDataByTime_ColumnHeaders = ('Time (min), Distance per minute (Km), Speed average (Km/h), Speed standard deviation (Km/h), Heart rate average (BPM), Heart rate standard deviation (BPM), Cadence average (rpm), Cadence standard deviation (rpm), Power average (Watts), Power standard deviation (Watts)');
        resultDataByTime_File = fopen(summaryDataByTimeFile, 'w+');
        fprintf(resultDataByTime_File, '%s', resultDataByTime_ColumnHeaders);
        fclose(resultDataByTime_File);
        dlmwrite(summaryDataByTimeFile, resultDataByTime, 'roffset', 1, '-append');
        % Data RPE
        
        %{
        Graphs are generated in this section if required.
        %}
    end
else
    disp('User selected Cancel');
end











