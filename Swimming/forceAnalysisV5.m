% This function reads the .csv file with the raw data obtained from the
% force plate. It resolves the force into x,y, and z components taking into
% account the angles of the main plate and the wedge. After the forces are
% resolved the take off point is found. The criteria is the last point
% above 20N on both plates. Peak forces and impulse are also determined.
% Changes on version 3:
%   1. The reaction time for the wedge has been added. The criteria used is described in this document.
%   2. Added check to prevent take off time to be smaller than reaction
%   time.
%   3. Changed the contact time to be based on the resolvedForces and not
%   the correctedData.
% TO DO:
%   1. Changed the take off time to be based on the resolvedForces and not
%   the correctedData. COMPLETED
%   2. Take into account if only one of the plates is used. COMPLETED
%   3. The criteria for reaction time on the main plate needs to be
%   modified.  If another criteria for reaction time is needed the reactionTimeFactorMainPlateAnalysis/reactionTimeFactorWedgeAnalysis 
%   must be set to true and the reactionTimeFactorMainPlate/reactionTimeFactorWedge to the desired
%   criteria value. COMPLETED
% PROCESS FOR REACTION TIME
%   1. The slope of the resolvedForces Y axis for the plate is calculated.
%   2. Data from the previous step is filtered using a moving average filter
%   with a span of 0.1s (this value can be modified changing the
%   minimumReactionTime value). The reasoning for using 0.1s is because
%   this is the threshold value to determine false starts.
%   3. The local maximums for the smoothed data are found using two
%   criteria:
%       1. 'minpeakheight': Set to the average value of the smoothed data
%       plus 1 standard deviation.
%       2. 'minpeakdistance': Set as the minimum distance between peaks.
%       The parameters for the previous criteria can be modified by
%       changing the minimumPeakDistance and
%       meanSlopeMainPlate/meanSlopeWedge variables.
%       4. Once the first significant maximum has been detected the reaction
%       time is defined as the time when this maximum happens.

%{
All variables needed to process the data files are defined in this section.
%}
clc;
clear;
samplingFrequency = 1000;
averagePeriod = samplingFrequency / 4;
contactTimeMainCriteria = 20;
contactTimeWedgeCriteria = 20;
reactionTimeFrequency = 100;
reactionTimeFactorMainPlate = 1;
reactionTimeFactorWedge = 1;
minimumReactionTime = 0.1;
minimumPeakDistance = 30;
minimumPeakDistanceMainPlate = 10;
analysisWindow = 1;
averageFilterSpan = (minimumReactionTime * samplingFrequency);
wedgeAnalysis = true;
mainPlateAnalysis = true;
reactionTimeFactorMainPlateAnalysis = true;
reactionTimeFactorWedgeAnalysis = true;

if mod(averageFilterSpan, 2) == 0
    averageFilterSpan = averageFilterSpan + 1;
end

[fileName, pathName, filterIndex] = uigetfile({'*.csv'},'Load Swim File', '/Users/heinzlugo/Documents/01 Postgraduate project/04 Swimming/21 July 2014 AM/');

if isequal(fileName,0)
    disp('User selected Cancel');
else
    filepath = strcat(pathName, fileName);
    rawData = csvread(filepath,1, 1);
    rawData = rawData(1:size(rawData, 1), 1:6);
    rawData(:, 5) = -1 * rawData(:, 5);
    rawData(:, 6) = -1 * rawData(:, 6);
    offset = mean(rawData(end - averagePeriod:end, :));
    correctedData = zeros(size(rawData, 1), 6);
    for i = 1:size(rawData, 1)
        correctedData(i, :) = rawData(i, :) - offset;
    end
        
%{
Forces are resolved in this section.
%}
    % Main plate forces
    resolvedForces(:, 1) = correctedData(:, 1); % Main plate x.
    resolvedForces(:,2) = correctedData(:,2).*cos(deg2rad(10)) + correctedData(:,3).*sin(deg2rad(10)); % Main plate y.
    resolvedForces(:,3) = correctedData(:,3).*cos(deg2rad(10)) - correctedData(:,2).*sin(deg2rad(10)); % Main plate z.
    % Wedge forces
    resolvedForces(:,4) = correctedData(:,4); % Wedge x. 
    resolvedForces(:,5) = correctedData(:,5).*cos(deg2rad(40)) + correctedData(:,6).*sin(deg2rad(40)); % Wedge y.
    resolvedForces(:,6) =  correctedData(:,6).*cos(deg2rad(40)) - correctedData(:,5).*sin(deg2rad(40)); % Wedge z.
    % Resultant forces
    resolvedForces(:,7) = resolvedForces(:,1) + resolvedForces(:,4); % Resultant x.
    resolvedForces(:,8) = resolvedForces(:,2) + resolvedForces(:,5); % Resultant y.
    resolvedForces(:,9) = resolvedForces(:,3) + resolvedForces(:,6); % Resultant z.
    
%{
    The reaction time based on the main plate y value is determined in this section. The criteria is described at the start of this file.
%}
    %{
    Main plate reaction time.
    %}
    slopeVectorMainPlate = zeros(size(resolvedForces, 1), 1);
    
    for i = 1:size(resolvedForces, 1)
        if i == 1
            slopeVectorMainPlate(i, 1) = 0;
        else
            slopeVectorMainPlate(i, 1) = (resolvedForces(i, 2) - resolvedForces(i-1, 2)) * samplingFrequency;
        end
    end
     
    [fmaxMainPlateReaction, fmaxLocsMainPlateReaction] = max(resolvedForces(:, 2));
    processedSlopeVectorMainPlate = zeros(fmaxLocsMainPlateReaction, 1);
     
    for i = 1:fmaxLocsMainPlateReaction
        if slopeVectorMainPlate(i, 1) < 0
            processedSlopeVectorMainPlate(i, 1) = 0;
        else
            processedSlopeVectorMainPlate(i, 1) = slopeVectorMainPlate(i, 1);
        end
    end
     
    if ((fmaxLocsMainPlateReaction - (analysisWindow * samplingFrequency)) > 0)
        smoothedSlopeVectorMainPlate = smooth(processedSlopeVectorMainPlate(fmaxLocsMainPlateReaction - (analysisWindow * samplingFrequency):fmaxLocsMainPlateReaction, 1), averageFilterSpan, 'moving'); 
    else
        smoothedSlopeVectorMainPlate = smooth(processedSlopeVectorMainPlate(1:fmaxLocsMainPlateReaction, 1), averageFilterSpan, 'moving');
    end
     
    [slopemaxMainPlate, slopemaxLocsMainPlate] = max(smoothedSlopeVectorMainPlate);
    meanSlopeMainPlate = mean(smoothedSlopeVectorMainPlate) + std(smoothedSlopeVectorMainPlate);
    [slopemaxMainPlatePeaks, slopemaxMainPlatePeaksLocs] = findpeaks( smoothedSlopeVectorMainPlate, 'minpeakheight',  meanSlopeMainPlate, 'minpeakdistance', minimumPeakDistanceMainPlate);
        
    if size(slopemaxMainPlatePeaks, 1) == 0
        mainPlateAnalysis = false;
        reactionTimeRawMainPlate = 0;
    else
        if reactionTimeFactorMainPlateAnalysis == false
            reactionTimeRawMainPlate = slopemaxMainPlatePeaksLocs(1, 1);
        else
            reactionTimeMainPlateCriteria = round(slopemaxMainPlatePeaks(1,1) * reactionTimeFactorMainPlate);
            testValueMainPlateReaction = round(abs(smoothedSlopeVectorMainPlate - reactionTimeMainPlateCriteria));
            calibrationMainPlateReactionVector = testValueMainPlateReaction(1:slopemaxMainPlatePeaksLocs(1, 1) ,1);
            minCalibrationMainPlateReactionVector = min(calibrationMainPlateReactionVector);
            
            for i = size(calibrationMainPlateReactionVector, 1):-1:1
                if (calibrationMainPlateReactionVector(i, 1) == minCalibrationMainPlateReactionVector)
                    reactionTimeRawMainPlate = i;
                    break
                end
            end
        end
        if (fmaxLocsMainPlateReaction - (analysisWindow * samplingFrequency) > 0)
            reactionTimeRawMainPlate = reactionTimeRawMainPlate + (fmaxLocsMainPlateReaction - (analysisWindow * samplingFrequency));         
        end
    end
    
    reactionTimeMainPlate = reactionTimeRawMainPlate / samplingFrequency;
         
    %{
    Wedge reaction time
    %}
    slopeVectorWedge = zeros(size(resolvedForces, 1), 1);
    
    for i = 1:size(resolvedForces, 1)
        if i == 1
            slopeVectorWedge(i, 1) = 0;
        else
            slopeVectorWedge(i, 1) = (resolvedForces(i, 5) - resolvedForces(i-1, 5)) * samplingFrequency;
        end
     end
     
    [fmaxWedgeReaction, fmaxLocsWedgeReaction] = max(resolvedForces(:, 5));
    processedSlopeVectorWedge = zeros(fmaxLocsWedgeReaction, 1);
     
    for i = 1: fmaxLocsWedgeReaction
        if slopeVectorWedge(i, 1) < 0
            processedSlopeVectorWedge(i , 1) = 0;
        else
            processedSlopeVectorWedge(i, 1) = slopeVectorWedge(i, 1);
        end
    end
    
    if ((fmaxLocsWedgeReaction - (analysisWindow * samplingFrequency)) > 0)
        smoothedSlopeVectorWedge = smooth(processedSlopeVectorWedge(fmaxLocsWedgeReaction - (analysisWindow * samplingFrequency):fmaxLocsWedgeReaction, 1), averageFilterSpan, 'moving'); 
    else
        smoothedSlopeVectorWedge = smooth(processedSlopeVectorWedge(1:fmaxLocsWedgeReaction, 1), averageFilterSpan, 'moving');
    end
     
     [slopemaxWedge, slopemaxLocsWedge] = max(smoothedSlopeVectorWedge);
     meanSlopeWedge = mean(smoothedSlopeVectorWedge) + std(smoothedSlopeVectorWedge);
     [slopemaxWedgePeaks, slopemaxWedgePeaksLocs] = findpeaks(smoothedSlopeVectorWedge, 'minpeakheight',  meanSlopeWedge, 'minpeakdistance', minimumPeakDistance);
        
     if size(slopemaxWedgePeaks, 1)  == 0
         wedgeAnalysis = false;
         reactionTimeRawWedge = 0;
     else
          if reactionTimeFactorWedgeAnalysis == false
              reactionTimeRawWedge = slopemaxWedgePeaksLocs(1, 1);
          else
              reactionTimeWedgeCriteria = round(slopemaxWedgePeaks(1,1) * reactionTimeFactorWedge);
              testValueWedgeReaction = round(abs(smoothedSlopeVectorWedge - reactionTimeWedgeCriteria));
              calibrationWedgeReactionVector = testValueWedgeReaction(1:slopemaxWedgePeaksLocs(1,1) ,1);
              minCalibrationWedgeReactionVector = min(calibrationWedgeReactionVector);
            
            for i = size(calibrationWedgeReactionVector, 1):-1:1
                if (calibrationWedgeReactionVector(i, 1) == minCalibrationWedgeReactionVector)
                    reactionTimeRawWedge = i;
                    break
                end
            end
          end
         if ((fmaxLocsWedgeReaction - (analysisWindow * samplingFrequency)) > 0)
             reactionTimeRawWedge = reactionTimeRawWedge + (fmaxLocsWedgeReaction - (analysisWindow * samplingFrequency));
         end
     end
     
     reactionTimeWedge = reactionTimeRawWedge / samplingFrequency;
        
%{
Take off point is determined in this section. Defined as last point above 20N.
%}
     if mainPlateAnalysis == false
         timeTakeOffRawMain = 0;
     else
         for i = 1:size(resolvedForces, 1)
             if resolvedForces(i,3) < contactTimeMainCriteria
                 timeTakeOffRawMain = i;     % Take off time from the main plate. 
                 break
             end
         end
         if timeTakeOffRawMain < reactionTimeRawMainPlate
             for i = size(resolvedForces, 1):-1:1
                 if resolvedForces(i, 3) > contactTimeMainCriteria
                     timeTakeOffRawMain = i;     % Take off time from the main plate.
                     break
                 end
             end
         end
     end
     
     if wedgeAnalysis == false
         timeTakeOffRawWedge = 0;
     else
         for i = 1:size(resolvedForces,1)
             if abs(resolvedForces(i,6)) < contactTimeWedgeCriteria 
                 timeTakeOffRawWedge = i;     % Take off time from the wedge.
                 break
             end
         end
         
         if timeTakeOffRawWedge < reactionTimeRawWedge
             for i = size(resolvedForces,1):-1:1
                 if abs(resolvedForces(i,6)) > contactTimeWedgeCriteria
                     timeTakeOffRawWedge = i;     % Take off time from the wedge.
                     break
                 end
             end
         end
     end
  
     timeTakeOffRawDifference = timeTakeOffRawMain -  timeTakeOffRawWedge; % Difference between take off time from the main plate and the wedge.
    
%{
Peak forces are determined in this section. The analysis is performed from the reaction time point to the contact time point.
%}
     if mainPlateAnalysis == false
         cropForceMainPlate = zeros(1, 3);
     else
         cropForceMainPlate = resolvedForces(reactionTimeRawMainPlate:timeTakeOffRawMain, 1:3);
     end
     if wedgeAnalysis == false
         cropForceWedge = zeros(1, 3);
     else
         cropForceWedge = resolvedForces(reactionTimeRawWedge:timeTakeOffRawWedge, 4:6);
     end
     
     [fmaxMainPlateChannels, fmaxlocsMainPlateChannels] = max(resolvedForces(:, 1:3));
     [fmaxWedgeChannels, fmaxlocsWedgeChannels] = max(resolvedForces(:, 4:6));
    
%{
Impulse is determined in this section.
%}
     impulseMainPlate = (cumtrapz(cropForceMainPlate))./samplingFrequency;
     totalImpulseMainPlate = impulseMainPlate(length(impulseMainPlate), :);
     impulseWedge = (cumtrapz(cropForceWedge))./samplingFrequency;
     totalImpulseWedge = impulseWedge(length(impulseWedge), :);
     
     ResultMain = [fmaxMainPlateChannels(2) (fmaxlocsMainPlateChannels(2)/samplingFrequency) fmaxMainPlateChannels(3) (fmaxlocsMainPlateChannels(3)/samplingFrequency) totalImpulseMainPlate(2) totalImpulseMainPlate(3) timeTakeOffRawMain/samplingFrequency]; % Order y, z
     ResultWedge = [fmaxWedgeChannels(2) (fmaxlocsWedgeChannels(2)/samplingFrequency) fmaxWedgeChannels(3) (fmaxlocsWedgeChannels(3)/samplingFrequency) totalImpulseWedge(2) totalImpulseWedge(3) timeTakeOffRawWedge/samplingFrequency]; % Order y, z

    Result = [ResultMain ResultWedge];     
    resultImport = [reactionTimeMainPlate reactionTimeWedge timeTakeOffRawMain/samplingFrequency timeTakeOffRawWedge/samplingFrequency fmaxMainPlateChannels(2) fmaxWedgeChannels(2) fmaxMainPlateChannels(3) fmaxWedgeChannels(3) (fmaxlocsMainPlateChannels(2)/samplingFrequency) (fmaxlocsWedgeChannels(2)/samplingFrequency) (fmaxlocsMainPlateChannels(3)/samplingFrequency) (fmaxlocsWedgeChannels(3)/samplingFrequency)];
        
%{
Figures are done in this section.
%}
    timeVector = zeros(size(resolvedForces,1), 1); 
    for i = 1:size(resolvedForces,1)
        timeVector(i, 1) = i * (1/samplingFrequency);
    end
    figure(1);
    clf;
    hold on;
    plot(timeVector(:,1), resolvedForces(:, 2), 'r');
    plot(timeVector(:,1), resolvedForces(:, 3), 'g');
    plot((fmaxlocsMainPlateChannels(1, 2:3)) / samplingFrequency, fmaxMainPlateChannels(1, 2:3), 'o');
    plot(reactionTimeRawMainPlate / samplingFrequency, resolvedForces(reactionTimeRawMainPlate, 2), '*');
    plot(timeTakeOffRawMain / samplingFrequency, resolvedForces(timeTakeOffRawMain, 3), 'd');
    legend('Main y', 'Main z','Maximum forces', 'Reaction time','Contact time');
    title('Main plate forces');
    ylabel('Force');
    xlabel('Time (s)');
    
    figure(2);
    clf;
    hold on;
    plot(timeVector(:,1), resolvedForces(:, 5), 'r');
    plot(timeVector(:,1), resolvedForces(:, 6), 'g');
    plot((fmaxlocsWedgeChannels(1, 2:3)) / samplingFrequency, fmaxWedgeChannels(1, 2:3), 'o');
    plot(reactionTimeRawWedge / samplingFrequency, resolvedForces(reactionTimeRawWedge, 5), '*');
    plot(timeTakeOffRawWedge / samplingFrequency, resolvedForces(timeTakeOffRawWedge, 5), 'd');
    legend('Main y', 'Main z','Maximum forces', 'Reaction time','Contact time');
    title('Wedge plate forces');
    ylabel('Force');
    xlabel('Time (s)');
end

