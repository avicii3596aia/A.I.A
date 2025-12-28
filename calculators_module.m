classdef calculators_module
    % CALCULATORS_MODULE - Contains all calculator functions for AIA
    % This module contains the Molarity Calculator and Media Preparation Calculator
    
    methods(Static)
        
        function MolarityCalculator(handles)
            % MOLARITY CALCULATOR - Calculate grams needed for target molarity
            % This function creates a complete molarity calculator window
            
            set(handles.statusText, 'String', 'Starting Molarity Calculator...');
            drawnow;
            
            try
                % Create molarity calculator window
                fig = figure('Name', 'Molarity Calculator', 'Position', [500 300 550 280], ...
                            'NumberTitle', 'off', 'MenuBar', 'none', 'Resize', 'off');

                % Add title
                uicontrol('Parent', fig, 'Style', 'text', 'Position', [20 240 510 25], ...
                          'String', 'Molarity Calculator - Calculate grams needed for target molarity', ...
                          'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                          'BackgroundColor', get(fig, 'Color'));

                % Chemical formula input
                uicontrol('Parent', fig, 'Style', 'text', 'Position', [20 200 150 20], ...
                          'String', 'Chemical Formula (e.g. NaCl):', 'HorizontalAlignment', 'left', ...
                          'BackgroundColor', get(fig, 'Color'));
                hFormula = uicontrol('Parent', fig, 'Style', 'edit', 'Position', [180 200 150 25], ...
                                     'BackgroundColor', 'white', 'FontSize', 10);

                % Desired Molarity input
                uicontrol('Parent', fig, 'Style', 'text', 'Position', [20 160 150 20], ...
                          'String', 'Desired Molarity (mol/L):', 'HorizontalAlignment', 'left', ...
                          'BackgroundColor', get(fig, 'Color'));
                hM = uicontrol('Parent', fig, 'Style', 'edit', 'Position', [180 160 100 25], ...
                               'BackgroundColor', 'white', 'FontSize', 10);

                % Volume input
                uicontrol('Parent', fig, 'Style', 'text', 'Position', [20 120 150 20], ...
                          'String', 'Volume (L):', 'HorizontalAlignment', 'left', ...
                          'BackgroundColor', get(fig, 'Color'));
                hV = uicontrol('Parent', fig, 'Style', 'edit', 'Position', [180 120 100 25], ...
                               'BackgroundColor', 'white', 'FontSize', 10);

                % Result display area (MUST be defined BEFORE the callbacks)
                hResult = uicontrol('Parent', fig, 'Style', 'text', 'Position', [350 120 180 110], ...
                                    'String', 'Enter formula and values', ...
                                    'FontSize', 11, 'HorizontalAlignment', 'left', ...
                                    'BackgroundColor', [0.95 0.95 0.95]);

                % Calculate button (defined AFTER hResult)
                uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Calculate', ...
                          'Position', [180 50 100 35], 'FontSize', 12, 'FontWeight', 'bold', ...
                          'Callback', @(~,~) calculators_module.calculateMolarity(hFormula, hM, hV, hResult, handles));

                % Clear button
                uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Clear', ...
                          'Position', [290 50 70 35], 'FontSize', 12, ...
                          'Callback', @(~,~) calculators_module.clearMolarity(hFormula, hM, hV, hResult, handles));

                % Close button
                uicontrol('Parent', fig, 'Style', 'pushbutton', 'String', 'Close', ...
                          'Position', [370 50 70 35], 'FontSize', 12, ...
                          'Callback', @(~,~) close(fig));

                % Example text
                uicontrol('Parent', fig, 'Style', 'text', 'Position', [20 40 300 25], ...
                          'String', 'Examples: NaCl, CaCl2, H2SO4, C6H12O6', ...
                          'FontSize', 9, 'FontStyle', 'italic', 'HorizontalAlignment', 'left', ...
                          'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', get(fig, 'Color'));

                % Update main GUI status
                set(handles.statusText, 'String', 'Molarity Calculator opened successfully');

            catch ME
                % Handle any errors
                set(handles.statusText, 'String', ['Error in Molarity Calculator: ' ME.message]);
                disp(getReport(ME, 'extended'));
            end
        end
        
        function calculateMolarity(hFormula, hM, hV, hResult, handles)
            % Calculate molarity callback function
            
            % Read inputs
            formula = strtrim(get(hFormula, 'String'));
            M_str = strtrim(get(hM, 'String'));
            V_str = strtrim(get(hV, 'String'));
            
            % Validate inputs
            if isempty(formula)
                set(hResult, 'String', 'Please enter a chemical formula');
                return;
            end
            
            M = str2double(M_str);
            V = str2double(V_str);
            
            if isempty(M_str) || isempty(V_str)
                set(hResult, 'String', 'Please enter molarity and volume');
                return;
            end
            
            if isnan(M) || isnan(V)
                set(hResult, 'String', 'Enter valid numeric values for molarity and volume');
                return;
            end
            
            if M <= 0 || V <= 0
                set(hResult, 'String', 'Molarity and volume must be positive');
                return;
            end
            
            % Parse formula and compute molecular weight
            try
                MW = calculators_module.computeMW(formula);
            catch ME
                set(hResult, 'String', ['Formula Error: ' ME.message]);
                return;
            end
            
            % Compute grams needed
            grams = MW * M * V;
            
            % Display result with better formatting
            result_text = sprintf('Formula: %s\nMW: %.3f g/mol\n\nMass needed:\n%.4f g\n(%.2f mg)', ...
                                 formula, MW, grams, grams * 1000);
            set(hResult, 'String', result_text);
            
            % Update main GUI status
            set(handles.statusText, 'String', sprintf('Molarity calculation: %.4f g of %s needed', grams, formula));
        end
        
        function clearMolarity(hFormula, hM, hV, hResult, handles)
            % Clear all inputs and result
            set(hFormula, 'String', '');
            set(hM, 'String', '');
            set(hV, 'String', '');
            set(hResult, 'String', 'Enter formula and values');
            set(handles.statusText, 'String', 'Molarity Calculator - inputs cleared');
        end
        
        function MW = computeMW(formula)
            % Compute molecular weight from chemical formula
            
            % Tokenize elements and counts from chemical formula
            tokens = regexp(formula, '([A-Z][a-z]?)(\d*)', 'tokens');
            if isempty(tokens)
                error('Invalid chemical formula format');
            end
            
            aw = calculators_module.getAtomicWeights();
            MW = 0;
            
            for i = 1:numel(tokens)
                elem = tokens{i}{1};
                cnt = tokens{i}{2};
                
                % If no count specified, assume 1
                if isempty(cnt)
                    cnt = 1;
                else
                    cnt = str2double(cnt);
                    if isnan(cnt) || cnt <= 0
                        error('Invalid element count for %s', elem);
                    end
                end
                
                % Look up atomic weight
                if isfield(aw, elem)
                    MW = MW + aw.(elem) * cnt;
                else
                    error('Unknown element "%s"', elem);
                end
            end
        end
        
        function aw = getAtomicWeights()
            % Comprehensive atomic weights database (g/mol)
            
            % Main group elements
            aw.H  = 1.0079;   aw.He = 4.0026;   aw.Li = 6.941;    aw.Be = 9.0122;
            aw.B  = 10.811;   aw.C  = 12.0107;  aw.N  = 14.0067;  aw.O  = 15.9994;
            aw.F  = 18.9984;  aw.Ne = 20.1797;  aw.Na = 22.9897;  aw.Mg = 24.305;
            aw.Al = 26.9815;  aw.Si = 28.0855;  aw.P  = 30.9738;  aw.S  = 32.065;
            aw.Cl = 35.453;   aw.Ar = 39.948;   aw.K  = 39.0983;  aw.Ca = 40.078;
            
            % Transition metals (common ones)
            aw.Sc = 44.9559;  aw.Ti = 47.867;   aw.V  = 50.9415;  aw.Cr = 51.9961;
            aw.Mn = 54.938;   aw.Fe = 55.845;   aw.Co = 58.9332;  aw.Ni = 58.6934;
            aw.Cu = 63.546;   aw.Zn = 65.38;    aw.Ga = 69.723;   aw.Ge = 72.64;
            aw.As = 74.9216;  aw.Se = 78.96;    aw.Br = 79.904;   aw.Kr = 83.798;
            aw.Rb = 85.4678;  aw.Sr = 87.62;    aw.Y  = 88.9059;  aw.Zr = 91.224;
            aw.Nb = 92.9064;  aw.Mo = 95.96;    aw.Tc = 98;       aw.Ru = 101.07;
            aw.Rh = 102.9055; aw.Pd = 106.42;   aw.Ag = 107.8682; aw.Cd = 112.411;
            aw.In = 114.818;  aw.Sn = 118.71;   aw.Sb = 121.76;   aw.Te = 127.6;
            aw.I  = 126.9045; aw.Xe = 131.293;  aw.Cs = 132.9055; aw.Ba = 137.327;
            
            % Lanthanides (common ones)
            aw.La = 138.9055; aw.Ce = 140.116;  aw.Pr = 140.9077; aw.Nd = 144.242;
            aw.Pm = 145;      aw.Sm = 150.36;   aw.Eu = 151.964;  aw.Gd = 157.25;
            
            % Actinides (common ones)
            aw.Th = 232.0381; aw.Pa = 231.0359; aw.U  = 238.0289; aw.Np = 237;
            aw.Pu = 244;      aw.Am = 243;      aw.Cm = 247;
            
            % Heavy elements
            aw.Hf = 178.49;   aw.Ta = 180.9479; aw.W  = 183.84;   aw.Re = 186.207;
            aw.Os = 190.23;   aw.Ir = 192.217;  aw.Pt = 195.084;  aw.Au = 196.9666;
            aw.Hg = 200.59;   aw.Tl = 204.3833; aw.Pb = 207.2;    aw.Bi = 208.9804;
            aw.Po = 209;      aw.At = 210;      aw.Rn = 222;
        end
        
        function MediaPreparationCalculator(handles)
            % MEDIA PREPARATION CALCULATOR - Universal media preparation calculator
            % Single window interface with buttons for media selection and agar option
            
            set(handles.statusText, 'String', 'Starting Media Preparation Calculator...');
            drawnow;
            
            try
                % Create main figure
                fig = figure('Position', [300, 300, 400, 300], ...
                             'Name', 'Media Preparation Calculator', ...
                             'NumberTitle', 'off', ...
                             'Resize', 'off', ...
                             'MenuBar', 'none', ...
                             'ToolBar', 'none');
                
                % Media type selection
                uicontrol('Style', 'text', ...
                          'Position', [50, 250, 300, 20], ...
                          'String', 'Select Media Type:', ...
                          'FontSize', 10, ...
                          'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'left');
                
                % Media type buttons
                btnLB = uicontrol('Style', 'pushbutton', ...
                                  'Position', [30, 210, 100, 30], ...
                                  'String', 'LB Medium', ...
                                  'FontSize', 9);
                
                btnLBGM = uicontrol('Style', 'pushbutton', ...
                                    'Position', [140, 210, 100, 30], ...
                                    'String', 'LBGM Medium', ...
                                    'FontSize', 9);
                
                btnMSGG = uicontrol('Style', 'pushbutton', ...
                                    'Position', [250, 210, 100, 30], ...
                                    'String', 'MSGG(2x)', ...
                                    'FontSize', 9);
                
                % Agar option selection
                uicontrol('Style', 'text', ...
                          'Position', [50, 170, 300, 20], ...
                          'String', 'Agar Option:', ...
                          'FontSize', 10, ...
                          'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'left');
                
                % Agar buttons
                btnWithAgar = uicontrol('Style', 'pushbutton', ...
                                       'Position', [50, 130, 120, 30], ...
                                       'String', 'With Agar', ...
                                       'FontSize', 9);
                
                btnWithoutAgar = uicontrol('Style', 'pushbutton', ...
                                          'Position', [180, 130, 120, 30], ...
                                          'String', 'Without Agar', ...
                                          'FontSize', 9);
                
                % Volume input
                uicontrol('Style', 'text', ...
                          'Position', [50, 90, 150, 20], ...
                          'String', 'Volume (L):', ...
                          'FontSize', 10, ...
                          'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'left');
                
                volEdit = uicontrol('Style', 'edit', ...
                                   'Position', [200, 90, 100, 25], ...
                                   'String', '1', ...
                                   'FontSize', 9, ...
                                   'HorizontalAlignment', 'center');
                
                % Calculate button
                btnCalculate = uicontrol('Style', 'pushbutton', ...
                                        'Position', [150, 40, 100, 35], ...
                                        'String', 'Calculate', ...
                                        'FontSize', 10, ...
                                        'FontWeight', 'bold', ...
                                        'BackgroundColor', [0.2, 0.6, 0.2], ...
                                        'ForegroundColor', 'white');
                
                % Status display
                statusText = uicontrol('Style', 'text', ...
                                      'Position', [50, 10, 300, 20], ...
                                      'String', 'Select media type and agar option', ...
                                      'FontSize', 8, ...
                                      'ForegroundColor', [0.5, 0.5, 0.5], ...
                                      'HorizontalAlignment', 'center');
                
                % Store UI data in figure
                mediaData = struct();
                mediaData.selectedMedia = [];
                mediaData.includeAgar = [];
                mediaData.handles = handles;
                mediaData.statusText = statusText;
                mediaData.volEdit = volEdit;
                mediaData.btnLB = btnLB;
                mediaData.btnLBGM = btnLBGM;
                mediaData.btnMSGG = btnMSGG;
                mediaData.btnWithAgar = btnWithAgar;
                mediaData.btnWithoutAgar = btnWithoutAgar;
                setappdata(fig, 'mediaData', mediaData);
                
                % Set callbacks
                set(btnLB, 'Callback', @(~,~) calculators_module.selectMedia(fig, 1));
                set(btnLBGM, 'Callback', @(~,~) calculators_module.selectMedia(fig, 2));
                set(btnMSGG, 'Callback', @(~,~) calculators_module.selectMedia(fig, 3));
                set(btnWithAgar, 'Callback', @(~,~) calculators_module.selectAgar(fig, true));
                set(btnWithoutAgar, 'Callback', @(~,~) calculators_module.selectAgar(fig, false));
                set(btnCalculate, 'Callback', @(~,~) calculators_module.calculateMedia(fig));
                
                % Update main GUI status
                set(handles.statusText, 'String', 'Media Preparation Calculator opened successfully');
                
            catch ME
                % Handle any errors
                set(handles.statusText, 'String', ['Error in Media Preparation Calculator: ' ME.message]);
                disp(getReport(ME, 'extended'));
            end
        end
        
        function selectMedia(fig, mediaType)
            % Select media type callback
            
            mediaData = getappdata(fig, 'mediaData');
            mediaData.selectedMedia = mediaType;
            
            % Update button appearance
            set(mediaData.btnLB, 'BackgroundColor', [0.94, 0.94, 0.94]);
            set(mediaData.btnLBGM, 'BackgroundColor', [0.94, 0.94, 0.94]);
            set(mediaData.btnMSGG, 'BackgroundColor', [0.94, 0.94, 0.94]);
            
            if mediaType == 1
                set(mediaData.btnLB, 'BackgroundColor', [0.3, 0.6, 1]);
                set(mediaData.statusText, 'String', 'LB Medium selected');
            elseif mediaType == 2
                set(mediaData.btnLBGM, 'BackgroundColor', [0.3, 0.6, 1]);
                set(mediaData.statusText, 'String', 'LBGM Medium selected');
            elseif mediaType == 3
                set(mediaData.btnMSGG, 'BackgroundColor', [0.3, 0.6, 1]);
                set(mediaData.statusText, 'String', 'MSGG(2x) Medium selected');
            end
            
            setappdata(fig, 'mediaData', mediaData);
        end
        
        function selectAgar(fig, withAgar)
            % Select agar option callback
            
            mediaData = getappdata(fig, 'mediaData');
            mediaData.includeAgar = withAgar;
            
            % Update button appearance
            set(mediaData.btnWithAgar, 'BackgroundColor', [0.94, 0.94, 0.94]);
            set(mediaData.btnWithoutAgar, 'BackgroundColor', [0.94, 0.94, 0.94]);
            
            if withAgar
                set(mediaData.btnWithAgar, 'BackgroundColor', [0.3, 0.6, 1]);
                set(mediaData.statusText, 'String', 'With Agar selected');
            else
                set(mediaData.btnWithoutAgar, 'BackgroundColor', [0.3, 0.6, 1]);
                set(mediaData.statusText, 'String', 'Without Agar selected');
            end
            
            setappdata(fig, 'mediaData', mediaData);
        end
        
        function calculateMedia(fig)
            % Calculate media preparation
            
            mediaData = getappdata(fig, 'mediaData');
            
            % Validate inputs
            if isempty(mediaData.selectedMedia)
                set(mediaData.statusText, 'String', 'Please select a media type');
                return;
            end
            
            if isempty(mediaData.includeAgar)
                set(mediaData.statusText, 'String', 'Please select agar option');
                return;
            end
            
            % Get volume
            volStr = get(mediaData.volEdit, 'String');
            vol = str2double(volStr);
            
            if isnan(vol) || vol <= 0
                set(mediaData.statusText, 'String', 'Please enter a valid positive volume');
                return;
            end
            
            % Calculate based on media type
            if mediaData.selectedMedia == 1
                calculators_module.calculateLB(vol, mediaData.includeAgar, mediaData.handles);
            elseif mediaData.selectedMedia == 2
                calculators_module.calculateLBGM(vol, mediaData.includeAgar, mediaData.handles);
            elseif mediaData.selectedMedia == 3
                calculators_module.calculateMSGG(vol, mediaData.includeAgar, mediaData.handles);
            end
            
            set(mediaData.statusText, 'String', 'Calculation complete');
        end
        
        function calculateLB(vol, includeAgar, handles)
            % Calculate LB components
            
            gramsLB = 20 * vol;
            
            if includeAgar
                gramsAgar = 15 * vol;
                msg = sprintf(['For %.2f L of LB-agar solution, add:\n' ...
                              '• LB powder: %.2f g\n' ...
                              '• Agar: %.2f g'], vol, gramsLB, gramsAgar);
            else
                msg = sprintf('For %.2f L of LB solution, add:\n• LB powder: %.2f g', vol, gramsLB);
            end
            
            % Display result
            msgbox(msg, 'LB Preparation Results', 'help');
            set(handles.statusText, 'String', 'LB calculation complete');
        end
        
        function calculateLBGM(vol, includeAgar, handles)
            % Calculate LBGM components
            
            gramsLB = 20 * vol;    % g LB powder
            mLGlyc = 20 * vol;     % mL of 50% glycerol
            mLMnCl2 = 10 * vol;    % mL of 10 mM MnCl2 stock
            
            if includeAgar
                gramsAgar = 15 * vol;
                msg = sprintf(['For %.2f L of LBGM-agar solution, add:\n' ...
                              '• LB powder: %.2f g\n' ...
                              '• Glycerol (50%%): %.2f mL\n' ...
                              '• MnCl₂ (10 mM): %.2f mL\n' ...
                              '• Agar: %.2f g\n' ...
                              'Then bring up to %.2f L with DDW.'], ...
                              vol, gramsLB, mLGlyc, mLMnCl2, gramsAgar, vol);
            else
                msg = sprintf(['For %.2f L of LBGM solution (no agar), add:\n' ...
                              '• LB powder: %.2f g\n' ...
                              '• Glycerol (50%%): %.2f mL\n' ...
                              '• MnCl₂ (10 mM): %.2f mL\n' ...
                              'Then bring up to %.2f L with DDW.'], ...
                              vol, gramsLB, mLGlyc, mLMnCl2, vol);
            end
            
            % Display result
            msgbox(msg, 'LBGM Preparation Results', 'help');
            set(handles.statusText, 'String', 'LBGM calculation complete');
        end
        
        function calculateMSGG(vol, includeAgar, handles)
            % Calculate MSGG(2x) components - based on 0.5L reference
            % Scale all components proportionally to desired volume
            
            scaleFactor = vol / 0.5; % Reference is for 0.5L
            
            % Calculate components (scaled from 0.5L reference)
            mL_K2HPO4 = 3.075 * scaleFactor;      % 1M K₂HPO₄
            mL_KH2PO4 = 1.925 * scaleFactor;      % 1M KH₂PO₄  
            mL_MOPS = 100 * scaleFactor;          % 1M MOPS
            mL_MgCl2 = 2 * scaleFactor;           % 1M MgCl₂
            mL_MnCl2 = 5 * scaleFactor;           % 10mM MnCl₂
            mL_ZnCl2 = 0.1 * scaleFactor;         % 10mM ZnCl₂
            mL_CaCl2 = 0.7 * scaleFactor;         % 1M CaCl₂
            mL_Thiamine = 5 * scaleFactor;        % 10mM Thiamine
            mL_Phe = 5 * scaleFactor;             % 10mg/ml Phenylalanine
            mL_Trp = 5 * scaleFactor;             % 10mg/ml Tryptophan
            mL_Glycerol = 10 * scaleFactor;       % 50% glycerol
            mL_GlutAcid = 50 * scaleFactor;       % 10% Glutamic acid
            mL_Thr = 5 * scaleFactor;             % 10mg/ml Threonine
            mL_DDW = 302 * scaleFactor;           % DDW
            
            % FeCl₃ calculation depends on agar option
            if includeAgar
                mL_FeCl3 = 12.5 * scaleFactor;    % 5mM FeCl₃ for agar version
                gramsAgar = 15 * vol;             % Agar: 15 g per 1 L
                
                msg = sprintf(['For %.2f L of MSGG(2x)-agar solution, add:\n' ...
                              '• 1M K₂HPO₄: %.3f mL\n' ...
                              '• 1M KH₂PO₄: %.3f mL\n' ...
                              '• 1M MOPS: %.1f mL (filter fresh, Adjust to pH7 with 1N NaOH)\n' ...
                              '• 1M MgCl₂: %.1f mL\n' ...
                              '• 10mM MnCl₂: %.1f mL\n' ...
                              '• 10mM ZnCl₂: %.2f mL\n' ...
                              '• 1M CaCl₂: %.1f mL\n' ...
                              '• 10mM Thiamine: %.1f mL\n' ...
                              '• 10mg/ml Phenylalanine: %.1f mL (filter fresh)\n' ...
                              '• 10mg/ml Tryptophan: %.1f mL (filter fresh)\n' ...
                              '• 50%% Glycerol: %.1f mL\n' ...
                              '• 10%% Glutamic acid: %.1f mL (filter fresh)\n' ...
                              '• 10mg/ml Threonine: %.1f mL (filter fresh)\n' ...
                              '• 5mM FeCl₃: %.1f mL (keep separate, add when use)\n' ...
                              '• Agar: %.2f g\n' ...
                              '• DDW: %.1f mL'], ...
                              vol, mL_K2HPO4, mL_KH2PO4, mL_MOPS, mL_MgCl2, ...
                              mL_MnCl2, mL_ZnCl2, mL_CaCl2, mL_Thiamine, mL_Phe, ...
                              mL_Trp, mL_Glycerol, mL_GlutAcid, mL_Thr, mL_FeCl3, ...
                              gramsAgar, mL_DDW);
            else
                mL_FeCl3 = 10 * scaleFactor;      % 5mM FeCl₃ for liquid version
                
                msg = sprintf(['For %.2f L of MSGG(2x) solution, add:\n' ...
                              '• 1M K₂HPO₄: %.3f mL\n' ...
                              '• 1M KH₂PO₄: %.3f mL\n' ...
                              '• 1M MOPS: %.1f mL (filter fresh, Adjust to pH7 with 1N NaOH)\n' ...
                              '• 1M MgCl₂: %.1f mL\n' ...
                              '• 10mM MnCl₂: %.1f mL\n' ...
                              '• 10mM ZnCl₂: %.2f mL\n' ...
                              '• 1M CaCl₂: %.1f mL\n' ...
                              '• 10mM Thiamine: %.1f mL\n' ...
                              '• 10mg/ml Phenylalanine: %.1f mL (filter fresh)\n' ...
                              '• 10mg/ml Tryptophan: %.1f mL (filter fresh)\n' ...
                              '• 50%% Glycerol: %.1f mL\n' ...
                              '• 10%% Glutamic acid: %.1f mL (filter fresh)\n' ...
                              '• 10mg/ml Threonine: %.1f mL (filter fresh)\n' ...
                              '• 5mM FeCl₃: %.1f mL (keep separate, add when use)\n' ...
                              '• DDW: %.1f mL'], ...
                              vol, mL_K2HPO4, mL_KH2PO4, mL_MOPS, mL_MgCl2, ...
                              mL_MnCl2, mL_ZnCl2, mL_CaCl2, mL_Thiamine, mL_Phe, ...
                              mL_Trp, mL_Glycerol, mL_GlutAcid, mL_Thr, mL_FeCl3, mL_DDW);
            end
            
            % Display result
            msgbox(msg, 'MSGG(2x) Preparation Results', 'help');
            set(handles.statusText, 'String', 'MSGG(2x) calculation complete');
        end
        
    end
end