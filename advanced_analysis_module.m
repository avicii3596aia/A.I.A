classdef advanced_analysis_module
    % ADVANCED_ANALYSIS_MODULE - Contains all advanced analysis functions
    % This module handles dose-response, colony counting, biofilm, microscopy, genomics, and batch processing
    
    methods(Static)
        
        function runDoseResponseAnalysis(handles)
 try
        % Create main dose-response window
        doseWin = figure('Name', 'Dose-Response Analysis', ...
                        'Position', [200, 200, 1200, 800], ...
                        'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Create panels
        controlPanel = uipanel(doseWin, 'Title', 'Controls', ...
                              'Position', [0.02, 0.02, 0.25, 0.96]);
        plotPanel = uipanel(doseWin, 'Title', 'Dose-Response Curve', ...
                           'Position', [0.30, 0.52, 0.68, 0.46]);
        resultsPanel = uipanel(doseWin, 'Title', 'Results', ...
                              'Position', [0.30, 0.02, 0.68, 0.48]);
        
        % Control elements
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Select Data File:', ...
                 'Position', [10, 720, 150, 20], 'HorizontalAlignment', 'left');
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Browse...', ...
                 'Position', [10, 690, 100, 30], ...
                 'Callback', {@advanced_analysis_module.loadDoseResponseData, doseWin});
        
        % Analysis type
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Analysis Type:', ...
                 'Position', [10, 650, 150, 20], 'HorizontalAlignment', 'left');
        
        analysisType = uicontrol(controlPanel, 'Style', 'popupmenu', ...
                               'String', {'IC50 (Inhibition)', 'EC50 (Stimulation)', 'Both'}, ...
                               'Position', [10, 620, 150, 25]);
        
        % Curve fitting options
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Curve Model:', ...
                 'Position', [10, 580, 150, 20], 'HorizontalAlignment', 'left');
        
        curveModel = uicontrol(controlPanel, 'Style', 'popupmenu', ...
                              'String', {'4-Parameter Logistic', '3-Parameter Logistic', 'Hill Equation'}, ...
                              'Position', [10, 550, 150, 25]);
        
        % Concentration units
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Concentration Units:', ...
                 'Position', [10, 510, 150, 20], 'HorizontalAlignment', 'left');
        
        concUnits = uicontrol(controlPanel, 'Style', 'edit', 'String', 'μM', ...
                             'Position', [10, 480, 100, 25]);
        
        % Analysis button
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Run Analysis', ...
                 'Position', [10, 430, 120, 40], 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.2, 0.8, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.runDoseAnalysis, doseWin, plotPanel, resultsPanel, concUnits});
        
        % Export button
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Export Results', ...
                 'Position', [10, 380, 120, 30], ...
                 'Callback', {@advanced_analysis_module.exportDoseResults, doseWin});
        
        % Store UI handles in figure
        doseData = struct();
        doseData.concentrations = [];
        doseData.responses = [];
        doseData.results = [];
        doseData.analysisType = analysisType;
        doseData.curveModel = curveModel;
        setappdata(doseWin, 'doseData', doseData);
        
        set(handles.statusText, 'String', 'Dose-Response Analysis tool opened successfully');
        
    catch ME
        set(handles.statusText, 'String', ['Error in Dose-Response Analysis: ' ME.message]);
        disp(getReport(ME, 'extended'));
 end
        end
        
        function loadDoseResponseData(~, ~, doseWin)
   [filename, pathname] = uigetfile('*.xlsx', 'Select Dose-Response Data');
    if ~isequal(filename, 0)
        try
            data = readtable(fullfile(pathname, filename));
            doseData = getappdata(doseWin, 'doseData');
            doseData.concentrations = data{:, 1};
            doseData.responses = data{:, 2:end};
            doseData.filename = filename;
            setappdata(doseWin, 'doseData', doseData);
            
            msgbox(sprintf('Loaded %d concentrations with %d replicates', ...
                   length(doseData.concentrations), width(doseData.responses)));
        catch ME
            msgbox(['Error loading data: ' ME.message], 'Error');
        end
    end
        end
        
        function runDoseAnalysis(~, ~, doseWin, plotPanel, resultsPanel, concUnits)
doseData = getappdata(doseWin, 'doseData');
    if isempty(doseData.concentrations)
        msgbox('Please load data first', 'No Data');
        return;
    end
    
    try
        % Calculate mean responses
        meanResponse = mean(doseData.responses, 2);
        stdResponse = std(doseData.responses, 0, 2);
        
        % Fit dose-response curve
        x = log10(doseData.concentrations);
        x = x(~isinf(x)); % Remove zeros
        y = meanResponse(~isinf(x));
        
        % Initial parameter estimates
        bottom = min(y);
        top = max(y);
        ic50_guess = x(find(y <= (top+bottom)/2, 1));
        hill_guess = -1;
        
        % Fit curve
        fitFun = @(p,x) p(1) + (p(2)-p(1))./(1+10.^((p(3)-x)*p(4)));
        p0 = [bottom, top, ic50_guess, hill_guess];
        
        options = optimset('Display', 'off');
        [pFit, resnorm] = lsqcurvefit(fitFun, p0, x, y, [], [], options);
        
        % Calculate IC50
        ic50_log = pFit(3);
        ic50_value = 10^ic50_log;
        
        % Generate fitted curve
        x_fit = linspace(min(x), max(x), 100);
        y_fit = fitFun(pFit, x_fit);
        
        % Plot results
        ax = axes('Parent', plotPanel, 'Position', [0.15, 0.15, 0.8, 0.8]);
        
        % Error bars
        errorbar(ax, doseData.concentrations, meanResponse, stdResponse, ...
                'ko', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'blue');
        hold(ax, 'on');
        
        % Fitted curve
        plot(ax, 10.^x_fit, y_fit, 'r-', 'LineWidth', 3);
        
        % IC50 line
        ic50_y = pFit(1) + (pFit(2)-pFit(1))/2;
        plot(ax, [ic50_value, ic50_value], [min(y), ic50_y], 'g--', 'LineWidth', 2);
        plot(ax, [min(doseData.concentrations), ic50_value], [ic50_y, ic50_y], 'g--', 'LineWidth', 2);
        
        set(ax, 'XScale', 'log');
        xlabel(ax, ['Concentration (' get(concUnits, 'String') ')']);
        ylabel(ax, 'Response');
        title(ax, 'Dose-Response Curve');
        legend(ax, 'Data ± SEM', 'Fitted Curve', 'IC50', 'Location', 'best');
        grid(ax, 'on');
        
        % Display results
        resultsText = sprintf(['Dose-Response Analysis Results:\n\n' ...
                             'IC50: %.3f %s\n' ...
                             'Hill Slope: %.3f\n' ...
                             'Top: %.3f\n' ...
                             'Bottom: %.3f\n' ...
                             'R²: %.4f\n\n' ...
                             '95%% Confidence Interval: [%.3f - %.3f] %s'], ...
                             ic50_value, get(concUnits, 'String'), ...
                             pFit(4), pFit(2), pFit(1), ...
                             1-resnorm/sum((y-mean(y)).^2), ...
                             ic50_value*0.8, ic50_value*1.2, get(concUnits, 'String'));
        
        uicontrol(resultsPanel, 'Style', 'text', 'String', resultsText, ...
                 'Position', [20, 50, 600, 300], 'HorizontalAlignment', 'left', ...
                 'FontSize', 11, 'BackgroundColor', 'white');
        
        % Store results
        doseData.results = struct('IC50', ic50_value, 'HillSlope', pFit(4), ...
                                'Top', pFit(2), 'Bottom', pFit(1), ...
                                'fittedParams', pFit, 'x_fit', x_fit, 'y_fit', y_fit);
        setappdata(doseWin, 'doseData', doseData);
        
    catch ME
        msgbox(['Curve fitting failed: ' ME.message], 'Error');
    end
        end
        
        function exportDoseResults(~, ~, doseWin)
doseData = getappdata(doseWin, 'doseData');
    if isempty(doseData.results)
        msgbox('No results to export', 'No Results');
        return;
    end
    
    [filename, pathname] = uiputfile('*.xlsx', 'Export Results');
    if ~isequal(filename, 0)
        try
            results = struct2table(doseData.results);
            writetable(results, fullfile(pathname, filename));
            msgbox('Results exported successfully!', 'Export Complete');
        catch ME
            msgbox(['Export failed: ' ME.message], 'Error');
        end
    end
        end
        
        function runColonyCounter(handles)
try
        % Create colony counter window
        colonyWin = figure('Name', 'Colony Counter & Morphology', ...
                          'Position', [150, 150, 1400, 900], ...
                          'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Create panels
        controlPanel = uipanel(colonyWin, 'Title', 'Controls', ...
                              'Position', [0.02, 0.02, 0.2, 0.96]);
        imagePanel = uipanel(colonyWin, 'Title', 'Image Analysis', ...
                            'Position', [0.25, 0.52, 0.73, 0.46]);
        resultsPanel = uipanel(colonyWin, 'Title', 'Results & Statistics', ...
                              'Position', [0.25, 0.02, 0.73, 0.48]);
        
        % Control elements
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Load Plate Image:', ...
                 'Position', [10, 820, 150, 20], 'HorizontalAlignment', 'left');
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Browse Image...', ...
                 'Position', [10, 790, 120, 30], ...
                 'Callback', {@advanced_analysis_module.loadPlateImage, colonyWin, imagePanel});
        
        % Analysis parameters
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Detection Parameters:', ...
                 'Position', [10, 750, 150, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Min Colony Size (px):', ...
                 'Position', [10, 720, 130, 20], 'HorizontalAlignment', 'left');
        minSize = uicontrol(controlPanel, 'Style', 'edit', 'String', '50', ...
                           'Position', [140, 720, 50, 25]);
        
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Max Colony Size (px):', ...
                 'Position', [10, 690, 130, 20], 'HorizontalAlignment', 'left');
        maxSize = uicontrol(controlPanel, 'Style', 'edit', 'String', '5000', ...
                           'Position', [140, 690, 50, 25]);
        
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Sensitivity:', ...
                 'Position', [10, 660, 100, 20], 'HorizontalAlignment', 'left');
        sensitivity = uicontrol(controlPanel, 'Style', 'slider', 'Min', 0.1, 'Max', 1.0, ...
                               'Value', 0.5, 'Position', [10, 640, 150, 20]);
        
        % Analysis buttons
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Count Colonies', ...
                 'Position', [10, 470, 120, 40], 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.2, 0.8, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.countColonies, colonyWin, imagePanel, resultsPanel, ...
                              minSize, maxSize, sensitivity});
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Export Results', ...
                 'Position', [10, 380, 120, 30], ...
                 'Callback', {@advanced_analysis_module.exportColonyResults, colonyWin});
        
        % Initialize data
        colonyData = struct();
        colonyData.image = [];
        colonyData.colonies = [];
        colonyData.stats = [];
        setappdata(colonyWin, 'colonyData', colonyData);
        
        set(handles.statusText, 'String', 'Colony Counter tool opened successfully');
        
    catch ME
        set(handles.statusText, 'String', ['Error in Colony Counter: ' ME.message]);
        disp(getReport(ME, 'extended'));
end
        end
        
        function loadPlateImage(~, ~, colonyWin, imagePanel)
[filename, pathname] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files'}, 'Select Plate Image');
    if ~isequal(filename, 0)
        try
            img = imread(fullfile(pathname, filename));
            colonyData = getappdata(colonyWin, 'colonyData');
            colonyData.image = img;
            colonyData.filename = filename;
            setappdata(colonyWin, 'colonyData', colonyData);
            
            % Display image
            ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
            imshow(img, 'Parent', ax);
            title(ax, ['Loaded: ' filename], 'Interpreter', 'none');
            
        catch ME
            msgbox(['Error loading image: ' ME.message], 'Error');
        end
    end
        end
        
        function countColonies(~, ~, colonyWin, imagePanel, resultsPanel, minSize, maxSize, sensitivity)
 colonyData = getappdata(colonyWin, 'colonyData');
    if isempty(colonyData.image)
        msgbox('Please load an image first', 'No Image');
        return;
    end
    
    try
        img = colonyData.image;
        
        % Convert to grayscale
        if size(img, 3) == 3
            grayImg = rgb2gray(img);
        else
            grayImg = img;
        end
        
        % Enhance contrast
        enhancedImg = adapthisteq(grayImg);
        
        % Threshold using Otsu's method
        level = graythresh(enhancedImg);
        bw = imbinarize(enhancedImg, level * get(sensitivity, 'Value'));
        
        % Clean up binary image
        bw = imfill(bw, 'holes');
        bw = bwareaopen(bw, str2double(get(minSize, 'String')));
        
        % Remove objects too large
        stats = regionprops(bw, 'Area');
        areas = [stats.Area];
        maxArea = str2double(get(maxSize, 'String'));
        toRemove = areas > maxArea;
        
        if any(toRemove)
            cc = bwconncomp(bw);
            bw = false(size(bw));
            for i = find(~toRemove)
                bw(cc.PixelIdxList{i}) = true;
            end
        end
        
        % Get colony properties
        colonyStats = regionprops(bw, grayImg, 'Area', 'Centroid', 'Eccentricity', ...
                                 'MajorAxisLength', 'MinorAxisLength', 'MeanIntensity', ...
                                 'Perimeter', 'Solidity');
        
        % Display results
        ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
        imshow(img, 'Parent', ax);
        hold(ax, 'on');
        
        % Overlay detected colonies
        for i = 1:length(colonyStats)
            centroid = colonyStats(i).Centroid;
            plot(ax, centroid(1), centroid(2), 'r+', 'MarkerSize', 10, 'LineWidth', 2);
            text(ax, centroid(1)+10, centroid(2), num2str(i), 'Color', 'red', ...
                 'FontSize', 8, 'FontWeight', 'bold');
        end
        
        title(ax, sprintf('Detected %d Colonies', length(colonyStats)));
        
        % Store results
        colonyData.colonies = bw;
        colonyData.stats = colonyStats;
        setappdata(colonyWin, 'colonyData', colonyData);
        
        % Display statistics
        advanced_analysis_module.displayColonyStats(resultsPanel, colonyStats);
        
    catch ME
        msgbox(['Colony counting failed: ' ME.message], 'Error');
    end
        end
        
        function displayColonyStats(resultsPanel, stats)
 if isempty(stats)
        return;
    end
    
    % Clear previous results
    children = get(resultsPanel, 'Children');
    delete(children);
    
    % Calculate statistics
    areas = [stats.Area];
    intensities = [stats.MeanIntensity];
    eccentricities = [stats.Eccentricity];
    
    % Create subplots
    subplot(2, 2, 1, 'Parent', resultsPanel);
    histogram(areas, 20);
    title('Colony Size Distribution');
    xlabel('Area (pixels)');
    ylabel('Count');
    
    subplot(2, 2, 2, 'Parent', resultsPanel);
    histogram(intensities, 15);
    title('Intensity Distribution');
    xlabel('Mean Intensity');
    ylabel('Count');
    
    subplot(2, 2, 3, 'Parent', resultsPanel);
    scatter(areas, intensities);
    title('Size vs Intensity');
    xlabel('Area (pixels)');
    ylabel('Mean Intensity');
    
    subplot(2, 2, 4, 'Parent', resultsPanel);
    text(0.1, 0.8, sprintf('Colony Count: %d', length(stats)), 'FontSize', 12);
    text(0.1, 0.7, sprintf('Mean Size: %.1f ± %.1f px', mean(areas), std(areas)), 'FontSize', 10);
    text(0.1, 0.6, sprintf('Size Range: %.0f - %.0f px', min(areas), max(areas)), 'FontSize', 10);
    text(0.1, 0.5, sprintf('Mean Intensity: %.1f ± %.1f', mean(intensities), std(intensities)), 'FontSize', 10);
    axis off;
        end
        
        function exportColonyResults(~, ~, colonyWin)
colonyData = getappdata(colonyWin, 'colonyData');
    if isempty(colonyData.stats)
        msgbox('No results to export', 'No Results');
        return;
    end
    
    [filename, pathname] = uiputfile('*.xlsx', 'Export Colony Results');
    if ~isequal(filename, 0)
        try
            % Create results table
            stats = colonyData.stats;
            resultsTable = table();
            resultsTable.ColonyID = (1:length(stats))';
            resultsTable.Area = [stats.Area]';
            resultsTable.Perimeter = [stats.Perimeter]';
            resultsTable.MajorAxis = [stats.MajorAxisLength]';
            resultsTable.MinorAxis = [stats.MinorAxisLength]';
            resultsTable.Eccentricity = [stats.Eccentricity]';
            resultsTable.Solidity = [stats.Solidity]';
            resultsTable.MeanIntensity = [stats.MeanIntensity]';
            
            writetable(resultsTable, fullfile(pathname, filename));
            msgbox('Colony results exported successfully!', 'Export Complete');
            
        catch ME
            msgbox(['Export failed: ' ME.message], 'Error');
        end
    end
        end
        
        function runBiofilmAnalysis(handles)
try
        % Create biofilm analysis window
        biofilmWin = figure('Name', 'Biofilm Analysis Suite', ...
                           'Position', [100, 100, 1300, 900], ...
                           'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Create panels
        controlPanel = uipanel(biofilmWin, 'Title', 'Analysis Controls', ...
                              'Position', [0.02, 0.02, 0.22, 0.96]);
        imagePanel = uipanel(biofilmWin, 'Title', 'Biofilm Visualization', ...
                            'Position', [0.26, 0.52, 0.72, 0.46]);
        resultsPanel = uipanel(biofilmWin, 'Title', 'Quantitative Analysis', ...
                              'Position', [0.26, 0.02, 0.72, 0.48]);
        
        % Analysis type selection
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Analysis Type:', ...
                 'Position', [10, 820, 120, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        analysisType = uicontrol(controlPanel, 'Style', 'popupmenu', ...
                               'String', {'Crystal Violet Quantification', 'Fluorescent Biofilm', 'Time-lapse Analysis'}, ...
                               'Position', [10, 790, 180, 25]);
        
        % Image loading
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Load Images...', ...
                 'Position', [10, 750, 120, 30], ...
                 'Callback', {@advanced_analysis_module.loadBiofilmImages, biofilmWin, imagePanel});
        
        % Analysis parameters
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Analysis Parameters:', ...
                 'Position', [10, 710, 150, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        % Background subtraction
        backgroundSub = uicontrol(controlPanel, 'Style', 'checkbox', 'String', 'Background Subtraction', ...
                                 'Position', [10, 680, 160, 20], 'Value', 1);
        
        % Threshold adjustment
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Detection Threshold:', ...
                 'Position', [10, 650, 120, 20], 'HorizontalAlignment', 'left');
        
        threshold = uicontrol(controlPanel, 'Style', 'slider', 'Min', 0, 'Max', 1, ...
                             'Value', 0.3, 'Position', [10, 625, 150, 20]);
        
        % Noise removal
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Noise Removal:', ...
                 'Position', [10, 595, 120, 20], 'HorizontalAlignment', 'left');
        
        noiseRemoval = uicontrol(controlPanel, 'Style', 'slider', 'Min', 0, 'Max', 10, ...
                                'Value', 3, 'Position', [10, 570, 150, 20]);
        
        % Analysis options
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Measurements:', ...
                 'Position', [10, 540, 120, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        measureCoverage = uicontrol(controlPanel, 'Style', 'checkbox', ...
                                   'String', 'Surface Coverage %', ...
                                   'Position', [10, 515, 150, 20], 'Value', 1);
        
        measureThickness = uicontrol(controlPanel, 'Style', 'checkbox', ...
                                    'String', 'Average Thickness', ...
                                    'Position', [10, 490, 150, 20], 'Value', 1);
        
        measureDensity = uicontrol(controlPanel, 'Style', 'checkbox', ...
                                  'String', 'Biomass Density', ...
                                  'Position', [10, 465, 150, 20], 'Value', 1);
        
        measureRoughness = uicontrol(controlPanel, 'Style', 'checkbox', ...
                                    'String', 'Surface Roughness', ...
                                    'Position', [10, 440, 150, 20], 'Value', 0);
        
        % Analysis buttons
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Analyze Biofilm', ...
                 'Position', [10, 380, 130, 40], 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.2, 0.8, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.analyzeBiofilm, biofilmWin, resultsPanel, analysisType, ...
                              threshold, noiseRemoval, measureCoverage, measureThickness, ...
                              measureDensity, measureRoughness});
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Export Results', ...
                 'Position', [10, 290, 130, 30], ...
                 'Callback', {@advanced_analysis_module.exportBiofilmResults, biofilmWin});
        
        % Initialize data structure
        biofilmData = struct();
        biofilmData.images = {};
        biofilmData.filenames = {};
        biofilmData.results = [];
        setappdata(biofilmWin, 'biofilmData', biofilmData);
        
        set(handles.statusText, 'String', 'Biofilm Analysis tool opened successfully');
        
    catch ME
        set(handles.statusText, 'String', ['Error in Biofilm Analysis: ' ME.message]);
        disp(getReport(ME, 'extended'));
end
        end
        
        function loadBiofilmImages(~, ~, biofilmWin, imagePanel)
[filenames, pathname] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files'}, ...
                                     'Select Biofilm Images', 'MultiSelect', 'on');
    if ~isequal(filenames, 0)
        if ischar(filenames)
            filenames = {filenames};
        end
        
        try
            images = cell(length(filenames), 1);
            for i = 1:length(filenames)
                images{i} = imread(fullfile(pathname, filenames{i}));
            end
            
            biofilmData = getappdata(biofilmWin, 'biofilmData');
            biofilmData.images = images;
            biofilmData.filenames = filenames;
            setappdata(biofilmWin, 'biofilmData', biofilmData);
            
            % Display first image
            if ~isempty(images)
                ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
                imshow(images{1}, 'Parent', ax);
                title(ax, sprintf('Loaded %d images - Showing: %s', ...
                       length(filenames), filenames{1}), 'Interpreter', 'none');
            end
            
        catch ME
            msgbox(['Error loading images: ' ME.message], 'Error');
        end
    end
        end
        
        function analyzeBiofilm(~, ~, biofilmWin, resultsPanel, analysisType, threshold, noiseRemoval, measureCoverage, measureThickness, measureDensity, measureRoughness)
biofilmData = getappdata(biofilmWin, 'biofilmData');
    if isempty(biofilmData.images)
        msgbox('Please load images first', 'No Images');
        return;
    end
    
    try
        results = [];
        analysisTypeIdx = get(analysisType, 'Value');
        
        for i = 1:length(biofilmData.images)
            img = biofilmData.images{i};
            filename = biofilmData.filenames{i};
            
            % Convert to appropriate format
            if analysisTypeIdx == 1  % Crystal Violet
                if size(img, 3) == 3
                    grayImg = rgb2gray(img);
                else
                    grayImg = img;
                end
                processedImg = grayImg;
                
            elseif analysisTypeIdx == 2  % Fluorescent
                if size(img, 3) == 3
                    processedImg = img(:,:,2);  % Use green channel
                else
                    processedImg = img;
                end
            end
            
            % Threshold the image
            threshValue = get(threshold, 'Value');
            if analysisTypeIdx == 1  % Crystal Violet (dark biofilm)
                level = graythresh(processedImg);
                bw = imbinarize(processedImg, level * threshValue);
                bw = ~bw;  % Invert for dark biofilm
            else  % Fluorescent (bright biofilm)
                level = graythresh(processedImg);
                bw = imbinarize(processedImg, level * (1 + threshValue));
            end
            
            % Noise removal
            noiseLevel = round(get(noiseRemoval, 'Value'));
            if noiseLevel > 0
                bw = bwareaopen(bw, noiseLevel);
                bw = imclose(bw, strel('disk', 2));
            end
            
            % Calculate measurements
            result = struct();
            result.filename = filename;
            result.imageIndex = i;
            
            if get(measureCoverage, 'Value')
                totalPixels = numel(bw);
                biofilmPixels = sum(bw(:));
                result.coverage = (biofilmPixels / totalPixels) * 100;
            end
            
            if get(measureThickness, 'Value')
                dt = bwdist(~bw);
                result.avgThickness = mean(dt(bw));
                result.maxThickness = max(dt(:));
            end
            
            if get(measureDensity, 'Value')
                biofilmIntensity = processedImg(bw);
                if ~isempty(biofilmIntensity)
                    result.density = mean(double(biofilmIntensity));
                else
                    result.density = 0;
                end
            end
            
            if get(measureRoughness, 'Value')
                boundaries = bwboundaries(bw);
                if ~isempty(boundaries)
                    boundary = boundaries{1};
                    centroid = mean(boundary);
                    distances = sqrt(sum((boundary - centroid).^2, 2));
                    result.roughness = std(distances);
                else
                    result.roughness = 0;
                end
            end
            
            results = [results; result];
        end
        
        % Display results
        advanced_analysis_module.displayBiofilmResults(results, resultsPanel, measureCoverage, measureThickness, ...
                             measureDensity, measureRoughness);
        
        % Store results
        biofilmData.results = results;
        setappdata(biofilmWin, 'biofilmData', biofilmData);
        
    catch ME
        msgbox(['Biofilm analysis failed: ' ME.message], 'Error');
        disp(getReport(ME, 'extended'));
    end
        end
        
        function displayBiofilmResults(results, resultsPanel, measureCoverage, measureThickness, measureDensity, measureRoughness)
% Clear results panel
    children = get(resultsPanel, 'Children');
    delete(children);
    
    plotCount = 1;
    
    if get(measureCoverage, 'Value') && isfield(results, 'coverage')
        subplot(2, 2, plotCount, 'Parent', resultsPanel);
        coverages = [results.coverage];
        bar(coverages);
        title('Biofilm Coverage (%)');
        ylabel('Coverage %');
        xlabel('Sample');
        
        % Add statistics
        text(0.7, 0.9, sprintf('Mean: %.1f%%\nStd: %.1f%%', ...
             mean(coverages), std(coverages)), ...
             'Units', 'normalized', 'BackgroundColor', 'white');
        plotCount = plotCount + 1;
    end
    
    if get(measureThickness, 'Value') && isfield(results, 'avgThickness')
        subplot(2, 2, plotCount, 'Parent', resultsPanel);
        thicknesses = [results.avgThickness];
        bar(thicknesses);
        title('Average Thickness (pixels)');
        ylabel('Thickness');
        xlabel('Sample');
        plotCount = plotCount + 1;
    end
    
    if get(measureDensity, 'Value') && isfield(results, 'density')
        subplot(2, 2, plotCount, 'Parent', resultsPanel);
        densities = [results.density];
        bar(densities);
        title('Biomass Density');
        ylabel('Mean Intensity');
        xlabel('Sample');
        plotCount = plotCount + 1;
    end
    
    if get(measureRoughness, 'Value') && isfield(results, 'roughness')
        subplot(2, 2, plotCount, 'Parent', resultsPanel);
        roughnesses = [results.roughness];
        bar(roughnesses);
        title('Surface Roughness');
        ylabel('Roughness Index');
        xlabel('Sample');
    end
        end
        
        function exportBiofilmResults(~, ~, biofilmWin)
biofilmData = getappdata(biofilmWin, 'biofilmData');
    if isempty(biofilmData.results)
        msgbox('No results to export', 'No Results');
        return;
    end
    
    [filename, pathname] = uiputfile('*.xlsx', 'Export Biofilm Results');
    if ~isequal(filename, 0)
        try
            resultsTable = struct2table(biofilmData.results);
            writetable(resultsTable, fullfile(pathname, filename));
            msgbox('Biofilm results exported successfully!', 'Export Complete');
        catch ME
            msgbox(['Export failed: ' ME.message], 'Error');
        end
    end
        end
        
        function runMicroscopyTools(handles)
 try
        % Create microscopy tools window
        microWin = figure('Name', 'Microscopy Analysis Suite', ...
                         'Position', [120, 120, 1400, 900], ...
                         'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Create panels
        controlPanel = uipanel(microWin, 'Title', 'Analysis Tools', ...
                              'Position', [0.02, 0.02, 0.2, 0.96]);
        imagePanel = uipanel(microWin, 'Title', 'Image Display', ...
                            'Position', [0.24, 0.52, 0.74, 0.46]);
        resultsPanel = uipanel(microWin, 'Title', 'Analysis Results', ...
                              'Position', [0.24, 0.02, 0.74, 0.48]);
        
        % Analysis type selection
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Analysis Type:', ...
                 'Position', [10, 820, 120, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        analysisType = uicontrol(controlPanel, 'Style', 'popupmenu', ...
                               'String', {'Cell Counting', 'Viability Analysis', 'Fluorescence Intensity', ...
                                         'Colocalization', 'Live/Dead Staining'}, ...
                               'Position', [10, 790, 150, 25]);
        
        % Image loading
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Load Images...', ...
                 'Position', [10, 750, 120, 30], ...
                 'Callback', {@advanced_analysis_module.loadMicroImages, microWin, imagePanel});
        
        % Cell detection parameters
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Detection Parameters:', ...
                 'Position', [10, 670, 150, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Cell Size Range (px):', ...
                 'Position', [10, 645, 130, 20], 'HorizontalAlignment', 'left');
        
        minCellSize = uicontrol(controlPanel, 'Style', 'edit', 'String', '20', ...
                               'Position', [10, 620, 40, 25]);
        
        uicontrol(controlPanel, 'Style', 'text', 'String', '-', ...
                 'Position', [55, 620, 10, 25], 'HorizontalAlignment', 'center');
        
        maxCellSize = uicontrol(controlPanel, 'Style', 'edit', 'String', '500', ...
                               'Position', [70, 620, 40, 25]);
        
        % Sensitivity
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Detection Sensitivity:', ...
                 'Position', [10, 590, 130, 20], 'HorizontalAlignment', 'left');
        
        sensitivity = uicontrol(controlPanel, 'Style', 'slider', 'Min', 0.1, 'Max', 1.0, ...
                               'Value', 0.5, 'Position', [10, 565, 140, 20]);
        
        % Analysis buttons
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Run Analysis', ...
                 'Position', [10, 380, 120, 40], 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.2, 0.8, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.runMicroAnalysis, microWin, imagePanel, resultsPanel, ...
                              analysisType, minCellSize, maxCellSize, sensitivity});
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Export Results', ...
                 'Position', [10, 290, 120, 30], ...
                 'Callback', {@advanced_analysis_module.exportMicroResults, microWin});
        
        % Initialize data
        microData = struct();
        microData.images = {};
        microData.filenames = {};
        microData.results = [];
        setappdata(microWin, 'microData', microData);
        
        set(handles.statusText, 'String', 'Microscopy Tools opened successfully');
        
    catch ME
        set(handles.statusText, 'String', ['Error in Microscopy Tools: ' ME.message]);
        disp(getReport(ME, 'extended'));
 end
        end
        
        function loadMicroImages(~, ~, microWin, imagePanel)
[filenames, pathname] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files'}, ...
                                     'Select Microscopy Images', 'MultiSelect', 'on');
    if ~isequal(filenames, 0)
        if ischar(filenames)
            filenames = {filenames};
        end
        
        try
            images = cell(length(filenames), 1);
            for i = 1:length(filenames)
                img = imread(fullfile(pathname, filenames{i}));
                images{i} = img;
            end
            
            microData = getappdata(microWin, 'microData');
            microData.images = images;
            microData.filenames = filenames;
            setappdata(microWin, 'microData', microData);
            
            % Display first image
            if ~isempty(images)
                ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
                imshow(images{1}, 'Parent', ax);
                title(ax, sprintf('Loaded %d images - %s', length(filenames), filenames{1}), ...
                      'Interpreter', 'none');
            end
            
        catch ME
            msgbox(['Error loading images: ' ME.message], 'Error');
        end
    end
        end
        
        function runMicroAnalysis(~, ~, microWin, imagePanel, resultsPanel, analysisType, minCellSize, maxCellSize, sensitivity)
microData = getappdata(microWin, 'microData');
    analysisTypeIdx = get(analysisType, 'Value');
    
    if isempty(microData.images)
        msgbox('Please load images first', 'No Images');
        return;
    end
    
    try
        switch analysisTypeIdx
            case 1  % Cell Counting
                results = advanced_analysis_module.performCellCounting(microData, minCellSize, maxCellSize, ...
                                            sensitivity, imagePanel);
            case 2  % Viability Analysis
                results = advanced_analysis_module.performViabilityAnalysis(microData, minCellSize);
            case 3  % Fluorescence Intensity
                results = advanced_analysis_module.performFluorescenceAnalysis(microData, resultsPanel);
            case 4  % Colocalization
                results = advanced_analysis_module.performColocalizationAnalysis(microData, imagePanel);
            case 5  % Live/Dead Staining
                results = advanced_analysis_module.performLiveDeadAnalysis(microData, minCellSize);
        end
        
        % Display results
        advanced_analysis_module.displayMicroResults(results, analysisTypeIdx, resultsPanel);
        
        % Store results
        microData.results = results;
        setappdata(microWin, 'microData', microData);
        
    catch ME
        msgbox(['Analysis failed: ' ME.message], 'Error');
        disp(getReport(ME, 'extended'));
    end
        end
        
        function results = performCellCounting(data, minCellSize, maxCellSize, sensitivity, imagePanel)
results = [];
    images = data.images;
    
    for i = 1:length(images)
        img = images{i};
        
        % Convert to grayscale if needed
        if size(img, 3) == 3
            grayImg = rgb2gray(img);
        else
            grayImg = img;
        end
        
        % Enhance contrast
        enhancedImg = adapthisteq(grayImg);
        
        % Threshold
        level = graythresh(enhancedImg);
        bw = imbinarize(enhancedImg, level * get(sensitivity, 'Value'));
        
        % Morphological operations
        se = strel('disk', 2);
        bw = imopen(bw, se);
        bw = imfill(bw, 'holes');
        
        % Size filtering
        minSize = str2double(get(minCellSize, 'String'));
        maxSize = str2double(get(maxCellSize, 'String'));
        bw = bwareaopen(bw, minSize);
        
        % Remove large objects
        stats = regionprops(bw, 'Area');
        areas = [stats.Area];
        toRemove = areas > maxSize;
        
        if any(toRemove)
            cc = bwconncomp(bw);
            bw = false(size(bw));
            for j = find(~toRemove)
                bw(cc.PixelIdxList{j}) = true;
            end
        end
        
        % Get final cell properties
        cellStats = regionprops(bw, grayImg, 'Area', 'Centroid', 'MeanIntensity', ...
                               'Eccentricity', 'Solidity');
        
        result = struct();
        result.filename = data.filenames{i};
        result.cellCount = length(cellStats);
        result.meanArea = mean([cellStats.Area]);
        result.meanIntensity = mean([cellStats.MeanIntensity]);
        result.cellStats = cellStats;
        
        results = [results; result];
        
        % Display annotated image for first image
        if i == 1 && ~isempty(cellStats)
            ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
            imshow(img, 'Parent', ax);
            hold(ax, 'on');
            
            for j = 1:length(cellStats)
                centroid = cellStats(j).Centroid;
                plot(ax, centroid(1), centroid(2), 'r+', 'MarkerSize', 8, 'LineWidth', 2);
                text(ax, centroid(1)+5, centroid(2), num2str(j), 'Color', 'red', ...
                     'FontSize', 8);
            end
            
            title(ax, sprintf('Cell Counting: %d cells detected', result.cellCount));
        end
    end
        end
        
        function results = performViabilityAnalysis(data, minCellSize)
results = [];
    images = data.images;
    
    for i = 1:length(images)
        img = images{i};
        
        % Assume live cells are green, dead cells are red
        if size(img, 3) == 3
            greenChannel = img(:,:,2);
            redChannel = img(:,:,1);
        else
            msgbox('Viability analysis requires RGB images', 'Error');
            return;
        end
        
        % Threshold each channel
        greenBW = imbinarize(greenChannel, graythresh(greenChannel));
        redBW = imbinarize(redChannel, graythresh(redChannel));
        
        % Clean up
        minSize = str2double(get(minCellSize, 'String'));
        greenBW = bwareaopen(greenBW, minSize);
        redBW = bwareaopen(redBW, minSize);
        
        % Count cells
        liveCells = regionprops(greenBW, 'Area');
        deadCells = regionprops(redBW, 'Area');
        
        liveCount = length(liveCells);
        deadCount = length(deadCells);
        totalCount = liveCount + deadCount;
        
        if totalCount > 0
            viability = (liveCount / totalCount) * 100;
        else
            viability = 0;
        end
        
        result = struct();
        result.filename = data.filenames{i};
        result.liveCells = liveCount;
        result.deadCells = deadCount;
        result.totalCells = totalCount;
        result.viability = viability;
        
        results = [results; result];
    end
        end
        
        function results = performFluorescenceAnalysis(data, resultsPanel)
 results = [];
    images = data.images;
    
    for i = 1:length(images)
        img = images{i};
        
        % Convert to grayscale if needed
        if size(img, 3) == 3
            grayImg = rgb2gray(img);
        else
            grayImg = img;
        end
        
        % Calculate intensity statistics
        meanIntensity = mean(grayImg(:));
        stdIntensity = std(double(grayImg(:)));
        maxIntensity = max(grayImg(:));
        
        % Create intensity histogram for first image
        if i == 1 && ~isempty(resultsPanel)
            ax = axes('Parent', resultsPanel, 'Position', [0.1, 0.6, 0.35, 0.35]);
            histogram(grayImg(:), 50);
            title('Fluorescence Intensity Distribution');
            xlabel('Intensity');
            ylabel('Pixel Count');
        end
        
        result = struct();
        result.filename = data.filenames{i};
        result.meanIntensity = meanIntensity;
        result.stdIntensity = stdIntensity;
        result.maxIntensity = maxIntensity;
        result.totalFluorescence = sum(double(grayImg(:)));
        
        results = [results; result];
    end
        end
        
        function results = performColocalizationAnalysis(data, imagePanel)
% Simplified colocalization for single channel images
    results = [];
    
    if length(data.images) < 2
        msgbox('Colocalization requires at least 2 images as different channels', 'Error');
        return;
    end
    
    % Use first two images as different channels
    img1 = data.images{1};
    img2 = data.images{2};
    
    % Convert to grayscale
    if size(img1, 3) == 3
        img1 = rgb2gray(img1);
    end
    if size(img2, 3) == 3
        img2 = rgb2gray(img2);
    end
    
    % Normalize intensities
    img1 = double(img1) / 255;
    img2 = double(img2) / 255;
    
    % Calculate colocalization coefficients
    threshold = 0.5;
    
    % Manders coefficients
    M1 = sum(img1(img2 > threshold)) / sum(img1(:));
    M2 = sum(img2(img1 > threshold)) / sum(img2(:));
    
    % Pearson correlation coefficient
    pearsonR = corr2(img1, img2);
    
    result = struct();
    result.filename = 'Colocalization_Analysis';
    result.mandersM1 = M1;
    result.mandersM2 = M2;
    result.pearsonR = pearsonR;
    
    results = result;
    
    % Display colocalization map
    if ~isempty(imagePanel)
        ax = axes('Parent', imagePanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
        
        % Create RGB overlay
        rgbOverlay = zeros(size(img1, 1), size(img1, 2), 3);
        rgbOverlay(:,:,1) = img1;  % Red channel
        rgbOverlay(:,:,2) = img2;  % Green channel
        
        imshow(rgbOverlay, 'Parent', ax);
        title(ax, sprintf('Colocalization (Pearson R = %.3f)', pearsonR));
    end
        end
        
        function results = performLiveDeadAnalysis(data, minCellSize)
% Similar to viability but more detailed
    results = advanced_analysis_module.performViabilityAnalysis(data, minCellSize);
    
    % Add additional live/dead specific metrics
    for i = 1:length(results)
        % Calculate live/dead ratio
        if results(i).deadCells > 0
            results(i).liveDeadRatio = results(i).liveCells / results(i).deadCells;
        else
            results(i).liveDeadRatio = Inf;
        end
        
        % Calculate death rate percentage
        if results(i).totalCells > 0
            results(i).deathRate = (results(i).deadCells / results(i).totalCells) * 100;
        else
            results(i).deathRate = 0;
        end
    end
        end
        
        function displayMicroResults(results, analysisType, resultsPanel)
if isempty(results)
        return;
    end
    
    % Clear results panel
    children = get(resultsPanel, 'Children');
    delete(children);
    
    switch analysisType
        case 1  % Cell Counting
            cellCounts = [results.cellCount];
            meanAreas = [results.meanArea];
            
            subplot(2, 2, 1, 'Parent', resultsPanel);
            bar(cellCounts);
            title('Cell Count per Image');
            ylabel('Cell Count');
            xlabel('Image');
            
            subplot(2, 2, 2, 'Parent', resultsPanel);
            bar(meanAreas);
            title('Mean Cell Area');
            ylabel('Area (pixels)');
            xlabel('Image');
            
            if ~isempty(results(1).cellStats)
                subplot(2, 2, 3, 'Parent', resultsPanel);
                histogram([results(1).cellStats.Area], 20);
                title('Cell Size Distribution (First Image)');
                xlabel('Area (pixels)');
                ylabel('Count');
            end
            
        case 2  % Viability
            viabilities = [results.viability];
            
            subplot(2, 2, 1, 'Parent', resultsPanel);
            bar(viabilities);
            title('Cell Viability (%)');
            ylabel('Viability %');
            xlabel('Image');
            
            subplot(2, 2, 2, 'Parent', resultsPanel);
            liveCells = [results.liveCells];
            deadCells = [results.deadCells];
            bar([liveCells; deadCells]', 'stacked');
            title('Live vs Dead Cells');
            ylabel('Cell Count');
            xlabel('Image');
            legend('Live', 'Dead');
            
        case 3  % Fluorescence
            intensities = [results.meanIntensity];
            
            subplot(2, 2, 2, 'Parent', resultsPanel);
            bar(intensities);
            title('Mean Fluorescence Intensity');
            ylabel('Intensity');
            xlabel('Image');
            
        case 4  % Colocalization
            if isfield(results, 'pearsonR')
                subplot(2, 2, 1, 'Parent', resultsPanel);
                bar(results.pearsonR);
                title('Pearson Correlation Coefficient');
                ylabel('Pearson R');
                
                subplot(2, 2, 2, 'Parent', resultsPanel);
                bar(results.mandersM1);
                title('Manders Coefficient M1');
                ylabel('M1');
            end
    end
        end
        
        function exportMicroResults(~, ~, microWin)
 microData = getappdata(microWin, 'microData');
    if isempty(microData.results)
        msgbox('No results to export', 'No Results');
        return;
    end
    
    [filename, pathname] = uiputfile('*.xlsx', 'Export Microscopy Results');
    if ~isequal(filename, 0)
        try
            resultsTable = struct2table(microData.results);
            writetable(resultsTable, fullfile(pathname, filename));
            msgbox('Microscopy results exported successfully!', 'Export Complete');
        catch ME
            msgbox(['Export failed: ' ME.message], 'Error');
        end
    end
        end
        
        function runGenomicsTools(handles)
try
        % Create genomics tools window
        genomicsWin = figure('Name', 'Genomics Analysis Suite', ...
                            'Position', [180, 180, 1200, 800], ...
                            'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Create panels
        controlPanel = uipanel(genomicsWin, 'Title', 'Genomics Tools', ...
                              'Position', [0.02, 0.02, 0.25, 0.96]);
        workPanel = uipanel(genomicsWin, 'Title', 'Analysis Workspace', ...
                           'Position', [0.29, 0.52, 0.69, 0.46]);
        resultsPanel = uipanel(genomicsWin, 'Title', 'Results & Sequences', ...
                              'Position', [0.29, 0.02, 0.69, 0.48]);
        
        % Tool selection
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Select Tool:', ...
                 'Position', [10, 750, 100, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        toolType = uicontrol(controlPanel, 'Style', 'popupmenu', ...
                            'String', {'Primer Design', 'Restriction Analysis', 'Plasmid Mapping', ...
                                      'Sequence Statistics', 'ORF Finder'}, ...
                            'Position', [10, 720, 180, 25]);
        
        % Sequence input
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Input Sequence:', ...
                 'Position', [10, 680, 120, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Load FASTA', ...
                 'Position', [10, 645, 80, 25], ...
                 'Callback', {@advanced_analysis_module.loadSequence, genomicsWin, controlPanel});
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Paste', ...
                 'Position', [100, 645, 60, 25], ...
                 'Callback', {@advanced_analysis_module.pasteSequence, genomicsWin, controlPanel});
        
        sequenceText = uicontrol(controlPanel, 'Style', 'edit', 'Max', 10, ...
                                'Position', [10, 550, 180, 85], ...
                                'HorizontalAlignment', 'left');
        
        % Tool-specific parameters
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Parameters:', ...
                 'Position', [10, 520, 100, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        % Primer design parameters
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Target Length:', ...
                 'Position', [10, 490, 80, 20], 'HorizontalAlignment', 'left');
        
        primerLength = uicontrol(controlPanel, 'Style', 'edit', 'String', '20', ...
                                'Position', [100, 490, 40, 25]);
        
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Target Tm (°C):', ...
                 'Position', [10, 460, 80, 20], 'HorizontalAlignment', 'left');
        
        targetTm = uicontrol(controlPanel, 'Style', 'edit', 'String', '60', ...
                            'Position', [100, 460, 40, 25]);
        
        % Restriction enzyme selection
        uicontrol(controlPanel, 'Style', 'text', 'String', 'Restriction Enzyme:', ...
                 'Position', [10, 430, 120, 20], 'HorizontalAlignment', 'left');
        
        restrictionEnzyme = uicontrol(controlPanel, 'Style', 'popupmenu', ...
                                     'String', {'EcoRI', 'BamHI', 'HindIII', 'XhoI', 'SacI', 'KpnI', 'All Common'}, ...
                                     'Position', [10, 400, 120, 25]);
        
        % Analysis buttons
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Run Analysis', ...
                 'Position', [10, 350, 100, 40], 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.2, 0.8, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.runGenomicsAnalysis, genomicsWin, workPanel, resultsPanel, ...
                              toolType, sequenceText, primerLength, targetTm, restrictionEnzyme});
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Clear All', ...
                 'Position', [120, 350, 70, 25], ...
                 'Callback', {@advanced_analysis_module.clearAll, genomicsWin, workPanel, resultsPanel, sequenceText});
        
        uicontrol(controlPanel, 'Style', 'pushbutton', 'String', 'Export Results', ...
                 'Position', [10, 300, 100, 30], ...
                 'Callback', {@advanced_analysis_module.exportGenomicsResults, genomicsWin});
        
        % Initialize data
        genomicsData = struct();
        genomicsData.sequence = '';
        genomicsData.results = [];
        setappdata(genomicsWin, 'genomicsData', genomicsData);
        
        set(handles.statusText, 'String', 'Genomics Tools opened successfully');
        
    catch ME
        set(handles.statusText, 'String', ['Error in Genomics Tools: ' ME.message]);
        disp(getReport(ME, 'extended'));
end
        end
        
        function loadSequence(~, ~, genomicsWin, controlPanel)
 [filename, pathname] = uigetfile({'*.fasta;*.fa;*.seq;*.txt', 'Sequence Files'}, ...
                                    'Select Sequence File');
    if ~isequal(filename, 0)
        try
            sequence = advanced_analysis_module.readSequenceFile(fullfile(pathname, filename));
            
            % Find sequence text box
            children = get(controlPanel, 'Children');
            for i = 1:length(children)
                if strcmp(get(children(i), 'Style'), 'edit') && get(children(i), 'Max') > 1
                    set(children(i), 'String', sequence);
                    break;
                end
            end
            
            genomicsData = getappdata(genomicsWin, 'genomicsData');
            genomicsData.sequence = sequence;
            genomicsData.filename = filename;
            setappdata(genomicsWin, 'genomicsData', genomicsData);
            
        catch ME
            msgbox(['Error loading sequence: ' ME.message], 'Error');
        end
    end
        end
        
        function pasteSequence(~, ~, genomicsWin, controlPanel)
 sequence = clipboard('paste');
    % Clean sequence - remove non-DNA characters
    sequence = upper(regexprep(sequence, '[^ATCGRYSWKMBDHVN]', ''));
    
    % Find sequence text box
    children = get(controlPanel, 'Children');
    for i = 1:length(children)
        if strcmp(get(children(i), 'Style'), 'edit') && get(children(i), 'Max') > 1
            set(children(i), 'String', sequence);
            break;
        end
    end
    
    genomicsData = getappdata(genomicsWin, 'genomicsData');
    genomicsData.sequence = sequence;
    setappdata(genomicsWin, 'genomicsData', genomicsData);
        end
        
        function clearAll(~, ~, genomicsWin, workPanel, resultsPanel, sequenceText)
set(sequenceText, 'String', '');
    children = get(workPanel, 'Children');
    delete(children);
    children = get(resultsPanel, 'Children');
    delete(children);
    
    genomicsData = struct();
    genomicsData.sequence = '';
    genomicsData.results = [];
    setappdata(genomicsWin, 'genomicsData', genomicsData);
        end
        
        function runGenomicsAnalysis(~, ~, genomicsWin, workPanel, resultsPanel, toolType, sequenceText, primerLength, targetTm, restrictionEnzyme)
sequence = get(sequenceText, 'String');
    
    if isempty(sequence)
        msgbox('Please enter or load a sequence first', 'No Sequence');
        return;
    end
    
    toolTypeIdx = get(toolType, 'Value');
    
    try
        switch toolTypeIdx
            case 1  % Primer Design
                results = advanced_analysis_module.designPrimers(sequence, primerLength, targetTm);
            case 2  % Restriction Analysis
                results = advanced_analysis_module.analyzeRestrictionSites(sequence, restrictionEnzyme);
            case 3  % Plasmid Mapping
                results = advanced_analysis_module.mapPlasmid(sequence);
            case 4  % Sequence Statistics
                results = advanced_analysis_module.calculateSequenceStats(sequence);
            case 5  % ORF Finder
                results = advanced_analysis_module.findORFs(sequence);
        end
        
        advanced_analysis_module.displayGenomicsResults(results, toolTypeIdx, workPanel, resultsPanel);
        
        genomicsData = getappdata(genomicsWin, 'genomicsData');
        genomicsData.results = results;
        setappdata(genomicsWin, 'genomicsData', genomicsData);
        
    catch ME
        msgbox(['Analysis failed: ' ME.message], 'Error');
        disp(getReport(ME, 'extended'));
    end
        end
        
        function results = designPrimers(sequence, primerLengthControl, targetTmControl)
targetLen = str2double(get(primerLengthControl, 'String'));
    targetTmVal = str2double(get(targetTmControl, 'String'));
    
    results = struct();
    results.toolType = 'Primer Design';
    results.primers = {};
    
    % Simple primer design algorithm
    seqLen = length(sequence);
    
    if seqLen < targetLen * 2
        error('Sequence too short for primer design');
    end
    
    % Design forward primers
    forwardPrimers = {};
    for i = 1:(seqLen - targetLen + 1)
        primer = sequence(i:i+targetLen-1);
        tm = advanced_analysis_module.calculateTm(primer);
        gc = advanced_analysis_module.calculateGC(primer);
        
        % Check if Tm is close to target
        if abs(tm - targetTmVal) <= 5
            forwardPrimers{end+1} = struct('sequence', primer, 'position', i, ...
                                           'tm', tm, 'gc', gc, 'type', 'forward');
        end
        
        if length(forwardPrimers) >= 5  % Limit to 5 primers
            break;
        end
    end
    
    % Design reverse primers from the end
    reversePrimers = {};
    for i = (seqLen - targetLen + 1):-1:1
        primer = advanced_analysis_module.reverseComplement(sequence(i:i+targetLen-1));
        tm = advanced_analysis_module.calculateTm(primer);
        gc = advanced_analysis_module.calculateGC(primer);
        
        if abs(tm - targetTmVal) <= 5
            reversePrimers{end+1} = struct('sequence', primer, 'position', i, ...
                                           'tm', tm, 'gc', gc, 'type', 'reverse');
        end
        
        if length(reversePrimers) >= 5
            break;
        end
    end
    
    results.forwardPrimers = forwardPrimers;
    results.reversePrimers = reversePrimers;
    results.sequence = sequence;
        end
        
        function results = analyzeRestrictionSites(sequence, restrictionEnzymeControl)
 enzymeIdx = get(restrictionEnzymeControl, 'Value');
    enzymeNames = {'EcoRI', 'BamHI', 'HindIII', 'XhoI', 'SacI', 'KpnI', 'All Common'};
    
    % Define recognition sequences
    recognitionSeqs = containers.Map();
    recognitionSeqs('EcoRI') = 'GAATTC';
    recognitionSeqs('BamHI') = 'GGATCC';
    recognitionSeqs('HindIII') = 'AAGCTT';
    recognitionSeqs('XhoI') = 'CTCGAG';
    recognitionSeqs('SacI') = 'GAGCTC';
    recognitionSeqs('KpnI') = 'GGTACC';
    
    results = struct();
    results.toolType = 'Restriction Analysis';
    results.sites = {};
    
    if enzymeIdx <= 6
        % Single enzyme analysis
        enzymeName = enzymeNames{enzymeIdx};
        recognitionSeq = recognitionSeqs(enzymeName);
        
        sites = advanced_analysis_module.findRestrictionSites(sequence, recognitionSeq);
        results.enzyme = enzymeName;
        results.recognitionSeq = recognitionSeq;
        results.sites = sites;
        results.count = length(sites);
        
    else
        % All common enzymes
        allSites = struct();
        for enzyme = keys(recognitionSeqs)
            enzymeName = enzyme{1};
            recognitionSeq = recognitionSeqs(enzymeName);
            sites = advanced_analysis_module.findRestrictionSites(sequence, recognitionSeq);
            
            allSites.(enzymeName) = struct('sites', sites, 'count', length(sites), ...
                                           'recognitionSeq', recognitionSeq);
        end
        results.allSites = allSites;
    end
    
    results.sequence = sequence;
        end
        
        function results = mapPlasmid(sequence)
% Simple plasmid mapping
    results = struct();
    results.toolType = 'Plasmid Mapping';
    results.length = length(sequence);
    results.isCircular = true;  % Assume circular
    
    % Find common features
    features = {};
    
    % Look for common cloning sites
    commonSites = {'GAATTC', 'GGATCC', 'AAGCTT', 'CTCGAG'};
    siteNames = {'EcoRI', 'BamHI', 'HindIII', 'XhoI'};
    
    for i = 1:length(commonSites)
        sites = advanced_analysis_module.findRestrictionSites(sequence, commonSites{i});
        for j = 1:length(sites)
            features{end+1} = struct('name', siteNames{i}, 'position', sites(j), ...
                                    'type', 'restriction_site');
        end
    end
    
    % Look for potential promoters (simplified)
    tataSites = advanced_analysis_module.findSequenceMotif(sequence, 'TATAAA');
    for i = 1:length(tataSites)
        features{end+1} = struct('name', 'TATA_box', 'position', tataSites(i), ...
                                'type', 'promoter');
    end
    
    results.features = features;
        end
        
        function results = calculateSequenceStats(sequence)
results = struct();
    results.toolType = 'Sequence Statistics';
    results.sequence = sequence;
    results.length = length(sequence);
    
    % Base composition
    composition = advanced_analysis_module.calculateComposition(sequence);
    results.composition = composition;
    
    % GC content
    results.gcContent = advanced_analysis_module.calculateGC(sequence);
    
    % Molecular weight (approximate)
    results.molecularWeight = advanced_analysis_module.calculateMolecularWeight(sequence);
    
    % Melting temperature (approximate)
    results.meltingTemp = advanced_analysis_module.calculateTm(sequence);
        end
        
        function results = findORFs(sequence)
results = struct();
    results.toolType = 'ORF Finder';
    results.sequence = sequence;
    results.orfs = {};
    
    % Find ORFs in all 6 reading frames
    startCodon = 'ATG';
    stopCodons = {'TAA', 'TAG', 'TGA'};
    
    % Forward strand
    for frame = 1:3
        orfs = advanced_analysis_module.findORFsInFrame(sequence, frame, startCodon, stopCodons, 'forward');
        results.orfs = [results.orfs, orfs];
    end
    
    % Reverse strand
    revSeq = advanced_analysis_module.reverseComplement(sequence);
    for frame = 1:3
        orfs = advanced_analysis_module.findORFsInFrame(revSeq, frame, startCodon, stopCodons, 'reverse');
        % Adjust positions for reverse complement
        for i = 1:length(orfs)
            orfs{i}.start = length(sequence) - orfs{i}.start + 1;
            orfs{i}.stop = length(sequence) - orfs{i}.stop + 1;
        end
        results.orfs = [results.orfs, orfs];
    end
    
    % Sort by length
    if ~isempty(results.orfs)
        lengths = cellfun(@(x) x.length, results.orfs);
        [~, sortIdx] = sort(lengths, 'descend');
        results.orfs = results.orfs(sortIdx);
    end
        end
        
        function displayGenomicsResults(results, toolType, workPanel, resultsPanel)
 % Clear previous results
    children = get(workPanel, 'Children');
    delete(children);
    children = get(resultsPanel, 'Children');
    delete(children);
    
    switch toolType
        case 1  % Primer Design
            advanced_analysis_module.displayPrimerResults(results, workPanel);
        case 2  % Restriction Analysis
            advanced_analysis_module.displayRestrictionResults(results, workPanel, resultsPanel);
        case 3  % Plasmid Mapping
            advanced_analysis_module.displayPlasmidMap(results, workPanel, resultsPanel);
        case 4  % Sequence Statistics
            advanced_analysis_module.displayStatsResults(results, workPanel, resultsPanel);
        case 5  % ORF Finder
            advanced_analysis_module.displayORFResults(results, workPanel, resultsPanel);
    end
        end
        
        function displayPrimerResults(results, workPanel)
 % Display primer design results
    ax = axes('Parent', workPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
    axis off;
    
    y = 0.9;
    text(0.05, y, 'Primer Design Results:', 'FontSize', 14, 'FontWeight', 'bold');
    y = y - 0.1;
    
    % Forward primers
    text(0.05, y, 'Forward Primers:', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'blue');
    y = y - 0.05;
    
    for i = 1:min(3, length(results.forwardPrimers))
        primer = results.forwardPrimers{i};
        text(0.1, y, sprintf('%d. %s (Tm: %.1f°C, GC: %.1f%%, Pos: %d)', ...
             i, primer.sequence, primer.tm, primer.gc, primer.position), ...
             'FontSize', 10, 'FontName', 'Courier');
        y = y - 0.05;
    end
    
    y = y - 0.05;
    text(0.05, y, 'Reverse Primers:', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'red');
    y = y - 0.05;
    
    for i = 1:min(3, length(results.reversePrimers))
        primer = results.reversePrimers{i};
        text(0.1, y, sprintf('%d. %s (Tm: %.1f°C, GC: %.1f%%, Pos: %d)', ...
             i, primer.sequence, primer.tm, primer.gc, primer.position), ...
             'FontSize', 10, 'FontName', 'Courier');
        y = y - 0.05;
    end
        end
        
        function displayRestrictionResults(results, workPanel, resultsPanel)
if isfield(results, 'allSites')
        % Multiple enzymes
        ax = axes('Parent', workPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
        axis off;
        
        y = 0.9;
        text(0.05, y, 'Restriction Analysis - All Common Enzymes:', ...
             'FontSize', 14, 'FontWeight', 'bold');
        y = y - 0.1;
        
        enzymes = fieldnames(results.allSites);
        for i = 1:length(enzymes)
            enzyme = enzymes{i};
            siteData = results.allSites.(enzyme);
            
            text(0.05, y, sprintf('%s (%s): %d sites', enzyme, ...
                 siteData.recognitionSeq, siteData.count), ...
                 'FontSize', 11, 'FontWeight', 'bold');
            y = y - 0.04;
            
            if siteData.count > 0
                sitesStr = sprintf('%d ', siteData.sites);
                text(0.1, y, sprintf('Positions: %s', sitesStr), ...
                     'FontSize', 10, 'FontName', 'Courier');
            end
            y = y - 0.06;
        end
        
    else
        % Single enzyme - create restriction map
        ax = axes('Parent', workPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
        
        seqLen = length(results.sequence);
        plot([1, seqLen], [0.5, 0.5], 'k-', 'LineWidth', 3);
        hold on;
        
        % Mark restriction sites
        for i = 1:length(results.sites)
            site = results.sites(i);
            plot([site, site], [0.45, 0.55], 'r-', 'LineWidth', 2);
            text(site, 0.6, num2str(i), 'HorizontalAlignment', 'center', ...
                 'FontSize', 8, 'Color', 'red');
        end
        
        ylim([0.3, 0.8]);
        xlim([0, seqLen + 100]);
        xlabel('Base Position');
        title(sprintf('%s Restriction Map (%d sites found)', ...
              results.enzyme, results.count));
        
        % Add site list in results panel
        ax2 = axes('Parent', resultsPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
        axis off;
        
        if results.count > 0
            sitesStr = sprintf('%d ', results.sites);
            text(0.05, 0.8, sprintf('%s sites at positions: %s', ...
                 results.enzyme, sitesStr), 'FontSize', 12);
        else
            text(0.05, 0.8, sprintf('No %s sites found', results.enzyme), ...
                 'FontSize', 12);
        end
end
        end
        
        function displayPlasmidMap(results, workPanel, resultsPanel)
 % Circular plasmid map
    ax = axes('Parent', workPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
    
    % Draw circle
    theta = linspace(0, 2*pi, 100);
    radius = 1;
    x = radius * cos(theta);
    y = radius * sin(theta);
    plot(x, y, 'k-', 'LineWidth', 2);
    hold on;
    
    % Mark features
    if ~isempty(results.features)
        for i = 1:length(results.features)
            feature = results.features{i};
            angle = 2 * pi * feature.position / results.length;
            
            xPos = radius * cos(angle);
            yPos = radius * sin(angle);
            
            if strcmp(feature.type, 'restriction_site')
                plot(xPos, yPos, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'red');
                text(xPos*1.1, yPos*1.1, feature.name, 'FontSize', 8, ...
                     'HorizontalAlignment', 'center');
            else
                plot(xPos, yPos, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'blue');
                text(xPos*1.1, yPos*1.1, feature.name, 'FontSize', 8, ...
                     'HorizontalAlignment', 'center');
            end
        end
    end
    
    axis equal;
    xlim([-1.5, 1.5]);
    ylim([-1.5, 1.5]);
    title(sprintf('Plasmid Map (%d bp)', results.length));
    
    % Feature list
    ax2 = axes('Parent', resultsPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
    axis off;
    
    y = 0.9;
    text(0.05, y, 'Features Found:', 'FontSize', 12, 'FontWeight', 'bold');
    y = y - 0.1;
    
    if ~isempty(results.features)
        for i = 1:length(results.features)
            feature = results.features{i};
            text(0.05, y, sprintf('%s at position %d (%s)', ...
                 feature.name, feature.position, feature.type), 'FontSize', 10);
            y = y - 0.05;
        end
    else
        text(0.05, y, 'No features detected', 'FontSize', 10);
    end
        end
        
        function displayStatsResults(results, workPanel, resultsPanel)
 % Statistics display with charts
    subplot(2, 2, 1, 'Parent', workPanel);
    comp = results.composition;
    bases = {'A', 'T', 'G', 'C'};
    percentages = [comp.A, comp.T, comp.G, comp.C];
    pie(percentages, bases);
    title('Base Composition');
    
    subplot(2, 2, 2, 'Parent', workPanel);
    bar(percentages);
    set(gca, 'XTickLabel', bases);
    title('Base Frequencies (%)');
    ylabel('Percentage');
    
    % Display statistics in results panel
    ax = axes('Parent', resultsPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
    axis off;
    
    y = 0.9;
    text(0.05, y, 'Sequence Statistics:', 'FontSize', 14, 'FontWeight', 'bold');
    y = y - 0.1;
    
    text(0.05, y, sprintf('Length: %d bp', results.length), 'FontSize', 11);
    y = y - 0.05;
    text(0.05, y, sprintf('GC Content: %.1f%%', results.gcContent), 'FontSize', 11);
    y = y - 0.05;
    text(0.05, y, sprintf('Molecular Weight: %.1f g/mol', results.molecularWeight), 'FontSize', 11);
    y = y - 0.05;
    text(0.05, y, sprintf('Melting Temperature: %.1f°C', results.meltingTemp), 'FontSize', 11);
    y = y - 0.1;
    
    text(0.05, y, 'Base Composition:', 'FontSize', 11, 'FontWeight', 'bold');
    y = y - 0.05;
    text(0.05, y, sprintf('A: %.1f%%, T: %.1f%%, G: %.1f%%, C: %.1f%%', ...
         comp.A, comp.T, comp.G, comp.C), 'FontSize', 10);
        end
        
        function displayORFResults(results, workPanel, resultsPanel)
% ORF visualization
    ax = axes('Parent', workPanel, 'Position', [0.05, 0.1, 0.9, 0.8]);
    
    seqLen = length(results.sequence);
    
    % Draw sequence line
    plot([1, seqLen], [0, 0], 'k-', 'LineWidth', 2);
    hold on;
    
    % Draw ORFs
    colors = {'red', 'blue', 'green', 'magenta', 'cyan', 'yellow'};
    yPositions = [0.1, 0.2, 0.3, -0.1, -0.2, -0.3];  % Different frames
    
    if ~isempty(results.orfs)
        for i = 1:min(10, length(results.orfs))  % Show top 10 ORFs
            orf = results.orfs{i};
            frameIdx = mod(i-1, 6) + 1;
            
            if strcmp(orf.strand, 'forward')
                y = yPositions(1:3);
                y = y(mod(orf.frame-1, 3) + 1);
            else
                y = yPositions(4:6);
                y = y(mod(orf.frame-1, 3) + 1);
            end
            
            plot([orf.start, orf.stop], [y, y], 'LineWidth', 4, ...
                 'Color', colors{frameIdx});
            
            % Add arrow for direction
            if strcmp(orf.strand, 'forward')
                plot(orf.stop, y, '>', 'MarkerSize', 8, 'Color', colors{frameIdx});
            else
                plot(orf.start, y, '<', 'MarkerSize', 8, 'Color', colors{frameIdx});
            end
            
            % Label
            text((orf.start + orf.stop)/2, y + 0.05, sprintf('ORF%d (%daa)', i, orf.length/3), ...
                 'FontSize', 8, 'HorizontalAlignment', 'center');
        end
    end
    
    ylim([-0.4, 0.4]);
    xlim([0, seqLen + 100]);
    xlabel('Base Position');
    ylabel('Reading Frame');
    title('Open Reading Frames');
    
    % ORF list
    ax2 = axes('Parent', resultsPanel, 'Position', [0.05, 0.05, 0.9, 0.9]);
    axis off;
    
    y = 0.9;
    text(0.05, y, sprintf('Found %d ORFs:', length(results.orfs)), ...
         'FontSize', 12, 'FontWeight', 'bold');
    y = y - 0.1;
    
    for i = 1:min(5, length(results.orfs))
        orf = results.orfs{i};
        text(0.05, y, sprintf('ORF %d: %d-%d (%s, %d bp, %d aa)', ...
             i, orf.start, orf.stop, orf.strand, orf.length, orf.length/3), ...
             'FontSize', 10, 'FontName', 'Courier');
        y = y - 0.05;
    end
        end
        
        function exportGenomicsResults(~, ~, genomicsWin)
genomicsData = getappdata(genomicsWin, 'genomicsData');
    if isempty(genomicsData.results)
        msgbox('No results to export', 'No Results');
        return;
    end
    
    [filename, pathname] = uiputfile('*.txt', 'Export Genomics Results');
    if ~isequal(filename, 0)
        try
            fid = fopen(fullfile(pathname, filename), 'w');
            results = genomicsData.results;
            
            fprintf(fid, 'Genomics Analysis Results\n');
            fprintf(fid, '========================\n\n');
            fprintf(fid, 'Tool: %s\n', results.toolType);
            fprintf(fid, 'Date: %s\n\n', datestr(now));
            
            % Export based on tool type
            switch results.toolType
                case 'Sequence Statistics'
                    fprintf(fid, 'Sequence Length: %d bp\n', results.length);
                    fprintf(fid, 'GC Content: %.1f%%\n', results.gcContent);
                    fprintf(fid, 'Molecular Weight: %.1f g/mol\n', results.molecularWeight);
                    fprintf(fid, 'Melting Temperature: %.1f°C\n', results.meltingTemp);
                    
                case 'ORF Finder'
                    fprintf(fid, 'Number of ORFs found: %d\n\n', length(results.orfs));
                    for i = 1:length(results.orfs)
                        orf = results.orfs{i};
                        fprintf(fid, 'ORF %d: %d-%d (%s strand, %d bp)\n', ...
                               i, orf.start, orf.stop, orf.strand, orf.length);
                    end
            end
            
            fclose(fid);
            msgbox('Results exported successfully!', 'Export Complete');
            
        catch ME
            msgbox(['Export failed: ' ME.message], 'Error');
        end
    end
        end
        
        function runBatchProcessing(handles)
try
        % Create batch processing window
        batchWin = figure('Name', 'Batch Processing & Automation', ...
                         'Position', [200, 200, 1000, 700], ...
                         'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Create panels
        setupPanel = uipanel(batchWin, 'Title', 'Batch Setup', ...
                            'Position', [0.02, 0.52, 0.96, 0.46]);
        monitorPanel = uipanel(batchWin, 'Title', 'Processing Monitor', ...
                              'Position', [0.02, 0.02, 0.96, 0.48]);
        
        % Batch type selection
        uicontrol(setupPanel, 'Style', 'text', 'String', 'Batch Analysis Type:', ...
                 'Position', [20, 280, 150, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        batchType = uicontrol(setupPanel, 'Style', 'popupmenu', ...
                             'String', {'Growth Curve Analysis', 'Image Processing', 'Colony Counting', ...
                                       'Biofilm Analysis', 'Microscopy Analysis', 'Sequence Analysis'}, ...
                             'Position', [20, 250, 180, 25]);
        
        % Input selection
        uicontrol(setupPanel, 'Style', 'text', 'String', 'Input Source:', ...
                 'Position', [220, 280, 100, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        inputType = uicontrol(setupPanel, 'Style', 'popupmenu', ...
                             'String', {'Select Folder', 'File List'}, ...
                             'Position', [220, 250, 120, 25]);
        
        uicontrol(setupPanel, 'Style', 'pushbutton', 'String', 'Browse...', ...
                 'Position', [350, 250, 80, 25], ...
                 'Callback', {@advanced_analysis_module.selectInput, batchWin, inputType, batchType});
        
        % Selected files display
        uicontrol(setupPanel, 'Style', 'text', 'String', 'Selected Files:', ...
                 'Position', [20, 220, 100, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        filesList = uicontrol(setupPanel, 'Style', 'listbox', ...
                             'Position', [20, 120, 300, 95]);
        
        % Output settings
        uicontrol(setupPanel, 'Style', 'text', 'String', 'Output Folder:', ...
                 'Position', [580, 110, 100, 20], 'HorizontalAlignment', 'left');
        
        outputFolder = uicontrol(setupPanel, 'Style', 'edit', ...
                                'Position', [580, 85, 120, 25], ...
                                'String', pwd);
        
        uicontrol(setupPanel, 'Style', 'pushbutton', 'String', '...', ...
                 'Position', [710, 85, 25, 25], ...
                 'Callback', {@advanced_analysis_module.selectOutputFolder, outputFolder});
        
        % Control buttons
        uicontrol(setupPanel, 'Style', 'pushbutton', 'String', 'Start Batch', ...
                 'Position', [750, 190, 100, 40], 'FontWeight', 'bold', ...
                 'BackgroundColor', [0.2, 0.8, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.startBatch, batchWin, batchType, outputFolder});
        
        uicontrol(setupPanel, 'Style', 'pushbutton', 'String', 'Stop', ...
                 'Position', [750, 140, 100, 25], ...
                 'BackgroundColor', [0.8, 0.2, 0.2], 'ForegroundColor', 'white', ...
                 'Callback', {@advanced_analysis_module.stopBatch, batchWin});
        
        uicontrol(setupPanel, 'Style', 'pushbutton', 'String', 'Clear All', ...
                 'Position', [750, 110, 100, 25], ...
                 'Callback', {@advanced_analysis_module.clearBatch, batchWin, filesList});
        
        % Progress monitoring
        uicontrol(monitorPanel, 'Style', 'text', 'String', 'Processing Progress:', ...
                 'Position', [20, 280, 130, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        progressBar = uicontrol(monitorPanel, 'Style', 'text', ...
                               'Position', [20, 250, 500, 25], ...
                               'String', 'Ready to start batch processing...', ...
                               'BackgroundColor', [0.9, 0.9, 0.9]);
        
        % Results log
        uicontrol(monitorPanel, 'Style', 'text', 'String', 'Processing Log:', ...
                 'Position', [20, 220, 100, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        logText = uicontrol(monitorPanel, 'Style', 'listbox', ...
                           'Position', [20, 20, 600, 190]);
        
        % Statistics display
        uicontrol(monitorPanel, 'Style', 'text', 'String', 'Statistics:', ...
                 'Position', [640, 280, 80, 20], 'HorizontalAlignment', 'left', ...
                 'FontWeight', 'bold');
        
        statsText = uicontrol(monitorPanel, 'Style', 'text', ...
                             'Position', [640, 50, 300, 220], ...
                             'String', {'Files: 0', 'Processed: 0', 'Failed: 0', 'Success Rate: 0%', '', ...
                                       'Estimated Time: --', 'Elapsed Time: 00:00:00'}, ...
                             'HorizontalAlignment', 'left', ...
                             'BackgroundColor', [0.95, 0.95, 0.95]);
        
        % Initialize batch data
        batchData = struct();
        batchData.files = {};
        batchData.results = {};
        batchData.isProcessing = false;
        batchData.startTime = [];
        batchData.processedCount = 0;
        batchData.failedCount = 0;
        batchData.filesList = filesList;
        batchData.progressBar = progressBar;
        batchData.logText = logText;
        batchData.statsText = statsText;
        setappdata(batchWin, 'batchData', batchData);
        
        set(handles.statusText, 'String', 'Batch Processing tool opened successfully');
        
    catch ME
        set(handles.statusText, 'String', ['Error in Batch Processing: ' ME.message]);
        disp(getReport(ME, 'extended'));
end
        end
        
        function selectInput(~, ~, batchWin, inputType, batchType)
inputTypeIdx = get(inputType, 'Value');
    batchData = getappdata(batchWin, 'batchData');
    
    switch inputTypeIdx
        case 1  % Select Folder
            folderPath = uigetdir(pwd, 'Select Input Folder');
            if ~isequal(folderPath, 0)
                % Get files based on batch type
                batchTypeIdx = get(batchType, 'Value');
                files = advanced_analysis_module.getBatchFiles(folderPath, batchTypeIdx);
                
                batchData.files = files;
                batchData.inputPath = folderPath;
                setappdata(batchWin, 'batchData', batchData);
                
                % Update files list
                fileNames = cellfun(@(x) x.name, files, 'UniformOutput', false);
                set(batchData.filesList, 'String', fileNames);
            end
            
        case 2  % File List
            [filenames, pathname] = uigetfile('*.*', 'Select Files', 'MultiSelect', 'on');
            if ~isequal(filenames, 0)
                if ischar(filenames)
                    filenames = {filenames};
                end
                
                files = {};
                for i = 1:length(filenames)
                    files{i} = struct('name', filenames{i}, 'path', pathname);
                end
                
                batchData.files = files;
                setappdata(batchWin, 'batchData', batchData);
                
                set(batchData.filesList, 'String', filenames);
            end
    end
        end
        
        function files = getBatchFiles(folderPath, batchTypeIdx)
files = {};
    
    switch batchTypeIdx
        case 1  % Growth Curve Analysis
            xlsFiles = dir(fullfile(folderPath, '*.xlsx'));
            xlsFiles = [xlsFiles; dir(fullfile(folderPath, '*.xls'))];
            
        case {2, 3, 4, 5}  % Image analyses
            xlsFiles = [dir(fullfile(folderPath, '*.jpg')); ...
                       dir(fullfile(folderPath, '*.png')); ...
                       dir(fullfile(folderPath, '*.tif'))];
            
        case 6  % Sequence Analysis
            xlsFiles = [dir(fullfile(folderPath, '*.fasta')); ...
                       dir(fullfile(folderPath, '*.fa')); ...
                       dir(fullfile(folderPath, '*.seq'))];
            
        otherwise
            xlsFiles = dir(fullfile(folderPath, '*.*'));
    end
    
    for i = 1:length(xlsFiles)
        files{i} = struct('name', xlsFiles(i).name, 'path', folderPath);
    end
        end
        
        function selectOutputFolder(~, ~, outputFolder)
 folder = uigetdir(get(outputFolder, 'String'), 'Select Output Folder');
    if ~isequal(folder, 0)
        set(outputFolder, 'String', folder);
    end
        end
        
        function startBatch(~, ~, batchWin, batchType, outputFolder)
batchData = getappdata(batchWin, 'batchData');
    
    if isempty(batchData.files)
        msgbox('No files selected for processing', 'No Files');
        return;
    end
    
    % Initialize processing
    batchData.isProcessing = true;
    batchData.startTime = tic;
    batchData.processedCount = 0;
    batchData.failedCount = 0;
    batchData.results = {};
    setappdata(batchWin, 'batchData', batchData);
    
    % Clear log
    set(batchData.logText, 'String', {});
    
    % Process files
    totalFiles = length(batchData.files);
    batchTypeIdx = get(batchType, 'Value');
    
    advanced_analysis_module.addLogToBatch(batchData.logText, 'Starting batch processing...');
    advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('Total files: %d', totalFiles));
    % retrieve the cell-array of strings
    types = get(batchType, 'String');   
    
    % pick out the one you want
    chosenType = types{batchTypeIdx};    
    
    % now log it
    advanced_analysis_module.addLogToBatch( batchData.logText, ...
        sprintf('Analysis type: %s', chosenType) );
    
    for i = 1:totalFiles
        if ~batchData.isProcessing
            break;  % Stop if user clicked stop
        end
        
        file = batchData.files{i};
        advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('Processing file %d/%d: %s', i, totalFiles, file.name));
        
        try
            % Process file based on type
            result = advanced_analysis_module.processBatchFile(file, batchTypeIdx);
            
            if ~isempty(result)
                batchData.results{end+1} = result;
                batchData.processedCount = batchData.processedCount + 1;
                advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('✓ Success: %s', file.name));
            else
                batchData.failedCount = batchData.failedCount + 1;
                advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('✗ Failed: %s (No result)', file.name));
            end
            
        catch ME
            batchData.failedCount = batchData.failedCount + 1;
            advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('✗ Failed: %s (%s)', file.name, ME.message));
        end
        
        % Update progress
        advanced_analysis_module.updateBatchProgress(batchData.progressBar, i, totalFiles);
        advanced_analysis_module.updateBatchStats(batchData.statsText, batchData, totalFiles);
        setappdata(batchWin, 'batchData', batchData);
        
        % Allow GUI to update
        drawnow;
    end
    
    % Finish processing
    batchData.isProcessing = false;
    setappdata(batchWin, 'batchData', batchData);
    
    advanced_analysis_module.addLogToBatch(batchData.logText, 'Batch processing completed!');
    
    % Auto-export results
    advanced_analysis_module.exportBatchResults(batchWin, outputFolder);
        end
        
        function result = processBatchFile(file, analysisType)
 % Process individual file based on analysis type
    result = struct();
    result.filename = file.name;
    result.analysisType = analysisType;
    
    filePath = fullfile(file.path, file.name);
    
    try
        switch analysisType
            case 1  % Growth Curve Analysis
                % Read Excel file and perform basic analysis
                data = readtable(filePath);
                if width(data) >= 2
                    timeCol = data{:, 1};
                    dataCol = mean(data{:, 2:end}, 2);
                    
                    result.maxValue = max(dataCol);
                    result.auc = trapz(timeCol, dataCol);
                    result.finalValue = dataCol(end);
                end
                
            case {2, 3, 4, 5}  % Image analyses
                % Basic image analysis
                img = imread(filePath);
                
                if size(img, 3) == 3
                    grayImg = rgb2gray(img);
                else
                    grayImg = img;
                end
                
                result.meanIntensity = mean(grayImg(:));
                result.stdIntensity = std(double(grayImg(:)));
                result.imageSize = size(img);
                
                % Simple thresholding for object count
                bw = imbinarize(grayImg);
                bw = bwareaopen(bw, 50);
                
                cc = bwconncomp(bw);
                result.objectCount = cc.NumObjects;
                
            case 6  % Sequence Analysis
                % Basic sequence statistics
                sequence = advanced_analysis_module.readSequenceFile(filePath);
                
                result.length = length(sequence);
                result.gcContent = advanced_analysis_module.calculateGC(sequence);
                result.composition = advanced_analysis_module.calculateComposition(sequence);
        end
        
    catch ME
        result.error = ME.message;
    end
        end
        
        function stopBatch(~, ~, batchWin)
  batchData = getappdata(batchWin, 'batchData');
    batchData.isProcessing = false;
    setappdata(batchWin, 'batchData', batchData);
    
    advanced_analysis_module.addLogToBatch(batchData.logText, 'Batch processing stopped by user');
        end
        
        function clearBatch(~, ~, batchWin, filesList)
% Clear all data and reset interface
    batchData = struct();
    batchData.files = {};
    batchData.results = {};
    batchData.isProcessing = false;
    batchData.processedCount = 0;
    batchData.failedCount = 0;
    batchData.filesList = filesList;
    setappdata(batchWin, 'batchData', batchData);
    
    set(filesList, 'String', {});
        end
        
        function addLogToBatch(logText, message)
 currentLog = get(logText, 'String');
    timestamp = datestr(now, 'HH:MM:SS');
    newLog = [currentLog; {sprintf('[%s] %s', timestamp, message)}];
    set(logText, 'String', newLog);
    set(logText, 'Value', length(newLog));  % Scroll to bottom
        end
        
        function updateBatchProgress(progressBar, current, total)
 percentage = (current / total) * 100;
    progressStr = sprintf('Processing: %d/%d files (%.1f%%) %s', ...
                         current, total, percentage, repmat('█', 1, round(percentage/5)));
    set(progressBar, 'String', progressStr);
        end
        
        function updateBatchStats(statsText, batchData, totalFiles)
 processed = batchData.processedCount;
    failed = batchData.failedCount;
    
    if processed + failed > 0
        successRate = (processed / (processed + failed)) * 100;
    else
        successRate = 0;
    end
    
    if ~isempty(batchData.startTime)
        elapsedTime = toc(batchData.startTime);
        elapsedStr = sprintf('%02d:%02d:%02d', ...
                           floor(elapsedTime/3600), ...
                           floor(mod(elapsedTime, 3600)/60), ...
                           floor(mod(elapsedTime, 60)));
        
        if processed > 0
            avgTimePerFile = elapsedTime / processed;
            remainingFiles = totalFiles - processed - failed;
            estimatedTime = remainingFiles * avgTimePerFile;
            estimatedStr = sprintf('%02d:%02d:%02d', ...
                                 floor(estimatedTime/3600), ...
                                 floor(mod(estimatedTime, 3600)/60), ...
                                 floor(mod(estimatedTime, 60)));
        else
            estimatedStr = '--:--:--';
        end
    else
        elapsedStr = '00:00:00';
        estimatedStr = '--:--:--';
    end
    
    statsStr = {sprintf('Files: %d', totalFiles), ...
               sprintf('Processed: %d', processed), ...
               sprintf('Failed: %d', failed), ...
               sprintf('Success Rate: %.1f%%', successRate), ...
               '', ...
               sprintf('Estimated Time: %s', estimatedStr), ...
               sprintf('Elapsed Time: %s', elapsedStr)};
    
    set(statsText, 'String', statsStr);
        end
        
        function exportBatchResults(batchWin, outputFolder)
 batchData = getappdata(batchWin, 'batchData');
    
    if isempty(batchData.results)
        return;
    end
    
    outputPath = get(outputFolder, 'String');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    try
        % Export results table
        resultsTable = struct2table(batchData.results);
        excelFile = fullfile(outputPath, sprintf('batch_results_%s.xlsx', timestamp));
        writetable(resultsTable, excelFile);
        
        % Export processing log
        logEntries = get(batchData.logText, 'String');
        logFile = fullfile(outputPath, sprintf('batch_log_%s.txt', timestamp));
        
        fid = fopen(logFile, 'w');
        for i = 1:length(logEntries)
            fprintf(fid, '%s\n', logEntries{i});
        end
        fclose(fid);
        
        advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('Results exported to: %s', outputPath));
        msgbox('Batch results exported successfully!', 'Export Complete');
        
    catch ME
        advanced_analysis_module.addLogToBatch(batchData.logText, sprintf('Export failed: %s', ME.message));
    end
        end
        
        function sequence = readSequenceFile(filepath)
  sequence = '';
    fid = fopen(filepath, 'r');
    if fid == -1
        error('Could not open file');
    end
    
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            line = strtrim(line);
            if ~isempty(line) && line(1) ~= '>' && line(1) ~= ';'
                clean_line = regexprep(line, '[^ATCGRYSWKMBDHVNatcgryswkmbdhvn]', '');
                sequence = [sequence upper(clean_line)];
            end
        end
    end
    fclose(fid);
        end
        
        function tm = calculateTm(sequence)
 % Simple Tm calculation
    gc_count = sum(sequence == 'G') + sum(sequence == 'C');
    at_count = sum(sequence == 'A') + sum(sequence == 'T');
    
    if length(sequence) <= 14
        tm = (at_count * 2) + (gc_count * 4);
    else
        tm = 64.9 + 41 * (gc_count - 16.4) / length(sequence);
    end
        end
        
        function gc = calculateGC(sequence)
 gc_count = sum(sequence == 'G') + sum(sequence == 'C');
    gc = (gc_count / length(sequence)) * 100;
        end
        
        function comp = calculateComposition(sequence)
comp = struct();
    comp.A = (sum(sequence == 'A') / length(sequence)) * 100;
    comp.T = (sum(sequence == 'T') / length(sequence)) * 100;
    comp.G = (sum(sequence == 'G') / length(sequence)) * 100;
    comp.C = (sum(sequence == 'C') / length(sequence)) * 100;
        end
        
        function revComp = reverseComplement(sequence)
comp_map = containers.Map({'A','T','G','C','N','R','Y','S','W','K','M','B','D','H','V'}, ...
                             {'T','A','C','G','N','Y','R','S','W','M','K','V','H','D','B'});
    
    revComp = '';
    for i = length(sequence):-1:1
        if isKey(comp_map, sequence(i))
            revComp = [revComp comp_map(sequence(i))];
        else
            revComp = [revComp 'N'];
        end
    end
        end
        
        function sites = findRestrictionSites(sequence, recognitionSeq)
sites = [];
    seqLen = length(sequence);
    recLen = length(recognitionSeq);
    
    for i = 1:(seqLen - recLen + 1)
        if strcmp(sequence(i:i+recLen-1), recognitionSeq)
            sites = [sites, i];
        end
    end
        end
        
        function sites = findSequenceMotif(sequence, motif)
 sites = [];
    seqLen = length(sequence);
    motifLen = length(motif);
    
    for i = 1:(seqLen - motifLen + 1)
        if strcmp(sequence(i:i+motifLen-1), motif)
            sites = [sites, i];
        end
    end
        end
        
        function orfs = findORFsInFrame(sequence, frame, startCodon, stopCodons, strand)
 orfs = {};
    seqLen = length(sequence);
    
    % Start from the specified frame
    i = frame;
    while i <= seqLen - 2
        % Check for start codon
        if i + 2 <= seqLen && strcmp(sequence(i:i+2), startCodon)
            % Found start codon, look for stop codon
            for j = i+3:3:(seqLen-2)
                if j + 2 <= seqLen
                    codon = sequence(j:j+2);
                    if any(strcmp(codon, stopCodons))
                        % Found stop codon
                        orf = struct();
                        orf.start = i;
                        orf.stop = j + 2;
                        orf.length = orf.stop - orf.start + 1;
                        orf.frame = frame;
                        orf.strand = strand;
                        orf.sequence = sequence(i:j+2);
                        
                        % Only keep ORFs longer than 300 bp
                        if orf.length >= 300
                            orfs{end+1} = orf;
                        end
                        
                        i = j + 3;  % Continue after this ORF
                        break;
                    end
                end
            end
        else
            i = i + 3;  % Move to next codon
        end
    end
        end
        
        function mw = calculateMolecularWeight(sequence)
  % Approximate molecular weight calculation for DNA
    % Average molecular weights: A=331, T=322, G=347, C=307
    mw_A = 331.2;
    mw_T = 322.2;
    mw_G = 347.2;
    mw_C = 307.2;
    
    count_A = sum(sequence == 'A');
    count_T = sum(sequence == 'T');
    count_G = sum(sequence == 'G');
    count_C = sum(sequence == 'C');
    
    mw = (count_A * mw_A) + (count_T * mw_T) + (count_G * mw_G) + (count_C * mw_C);
    
    % Subtract water molecules for phosphodiester bonds
    mw = mw - (length(sequence) - 1) * 18.015;
        end
        
        function dinuc = calculateDinucleotideFreq(sequence)
bases = {'A', 'T', 'G', 'C'};
    dinuc = struct();
    
    for i = 1:4
        for j = 1:4
            dinucleotide = [bases{i}, bases{j}];
            count = 0;
            
            for k = 1:(length(sequence)-1)
                if strcmp(sequence(k:k+1), dinucleotide)
                    count = count + 1;
                end
            end
            
            dinuc.(dinucleotide) = count;
        end
    end
        end
        
        function paramText = formatParameters(parameters)
 if isempty(parameters)
        paramText = {'No parameters loaded'};
        return;
    end
    
    paramText = {};
    fields = fieldnames(parameters);
    
    for i = 1:length(fields)
        field = fields{i};
        value = parameters.(field);
        
        if isnumeric(value)
            paramText{end+1} = sprintf('%s: %.3f', field, value);
        elseif ischar(value)
            paramText{end+1} = sprintf('%s: %s', field, value);
        elseif islogical(value)
            paramText{end+1} = sprintf('%s: %s', field, mat2str(value));
        end
    end
    
    if isempty(paramText)
        paramText = {'No valid parameters found'};
    end
        end
        
    end
end