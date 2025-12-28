classdef image_analysis_module
    % IMAGE_ANALYSIS_MODULE - Contains all image processing and analysis functions
    % This module handles pellicle, bacterial growth, pore analysis, and Sanger sequencing
    
    methods(Static)
        
        function runPellicleIP(handles)
 try
        % Update status
        set(handles.statusText, 'String', 'Starting Pellicle IP Analysis...');
        drawnow;
        
        %% 1. Select image
        [fname,path] = uigetfile( ...
            {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff','Image Files'; ...
             '*.*','All Files'}, ...
            'Select an Image');
        if isequal(fname,0)
            set(handles.statusText, 'String', 'Pellicle IP Analysis canceled. Ready for next operation.');
            return;
        end
        imgPath = fullfile(path,fname);
        [~,base,~] = fileparts(fname);
        img = imread(imgPath);

        %% 2. Parameters dialog
        prompt = {'Number of groups:','Fixed radius:','Total circles:','Bar-graph title:'};
        dlgTitle = 'Pellicle IP Parameters';
        dims = [1 50;1 50;1 50;1 100];
        def  = {'3','50','10','Avg White % by Group'};
        answ = inputdlg(prompt,dlgTitle,dims,def);
        if isempty(answ)
            set(handles.statusText, 'String', 'Pellicle IP Analysis canceled. Ready for next operation.');
            return;
        end
        numG   = str2double(answ{1});
        r      = str2double(answ{2});
        totC   = round(str2double(answ{3}));
        gTitle = answ{4};
        assert(numG>=1 && r>0 && totC>=1,'Invalid parameters.');

        %% 3. Interactive marking
        set(handles.statusText, 'String', 'Pellicle IP: Mark circles on the image...');
        drawnow;
        
        figure('Name','Mark Circles','NumberTitle','off'); imshow(img);
        title('Left‐click to add a circle, Right‐click to remove one. Close when done.');
        hold on;
        centers = []; groups = []; handles_circles = gobjects(0);
        count = 0; gs = floor(totC/numG); cols = lines(numG);
        while ishandle(gcf) && count<totC
            waitforbuttonpress;
            sel = get(gcf,'SelectionType');
            pt  = get(gca,'CurrentPoint'); x = pt(1,1); y = pt(1,2);
            switch sel
              case 'normal'  % add
                count = count+1;
                centers(end+1,:) = [x y];
                g = min(ceil(count/gs),numG);
                groups(end+1) = g;
                handles_circles(end+1) = viscircles([x y],r,'EdgeColor',cols(g,:));
              case 'alt'     % remove
                if ~isempty(centers)
                  d = hypot(centers(:,1)-x,centers(:,2)-y);
                  [md,i] = min(d);
                  if md<=r
                    delete(handles_circles(i));
                    centers(i,:)=[]; groups(i)=[]; handles_circles(i)=[]; count=count-1;
                  end
                end
            end
        end
        hold off;
        if isempty(centers)
            set(handles.statusText, 'String', 'No circles marked. Pellicle IP Analysis canceled.');
            return;
        end

        %% 4. Grayscale analysis & annotation
        set(handles.statusText, 'String', 'Pellicle IP: Analyzing marked regions...');
        drawnow;
        
        gray = rgb2gray(img);
        figure('Name','Analysis','NumberTitle','off'); imshow(gray);
        title('Grayscale Image with Grouped Circles');
        hold on;
        n = size(centers,1);
        pct = zeros(n,1);
        for i = 1:n
            [XX,YY] = ndgrid((1:size(gray,1))-centers(i,2), ...
                             (1:size(gray,2))-centers(i,1));
            mask = XX.^2+YY.^2 <= r^2;
            pct(i) = mean(gray(mask))/255*100;
            c = cols(groups(i),:);
            viscircles(centers(i,:),r,'EdgeColor',c);
            text(centers(i,1),centers(i,2),num2str(groups(i)), ...
                 'Color',c,'FontSize',12,'HorizontalAlignment','center');
            text(centers(i,1),centers(i,2)+r+20,sprintf('%.2f%%',pct(i)), ...
                 'Color',c,'FontSize',10,'HorizontalAlignment','center');
        end
        hold off;
        saveas(gcf,fullfile(path,[base '_IP.png']));

        %% 5. Tables & Excel
        set(handles.statusText, 'String', 'Pellicle IP: Generating results and saving files...');
        drawnow;
        
        Tdet = table((1:n)',pct, ...
            'VariableNames',{'Circle','WhitePct'});
        Gavg = arrayfun(@(g)mean(pct(groups==g)),1:numG)';
        Gstd = arrayfun(@(g)std(pct(groups==g)),1:numG)';
        Ts   = table((1:numG)',Gavg,Gstd, ...
            'VariableNames',{'Group','AvgWhitePct','StdWhitePct'});
        xlsF = fullfile(path,[base '_results.xlsx']);
        writetable(Tdet,xlsF,'Sheet','Detailed');
        writetable(Ts,  xlsF,'Sheet','Summary');

        %% 6. Bar‑graph with custom colors
        figure('Name','Group Averages','NumberTitle','off');
        b = bar(Gavg);
        b.FaceColor = 'flat';
        b.CData = lines(numG);
        hold on;
        errorbar(1:numG,Gavg,Gstd,'k','LineStyle','none');
        xlabel('Group'); ylabel('Avg White %'); title(gTitle); grid on; hold off;
        saveas(gcf,fullfile(path,[base '_graph.png']));
        saveas(gcf,fullfile(path,[base '_graph.pdf']));

        %% 7. Threshold‑based marks & Excel sheet
        marks = cell(n,1);
        for i=1:n
          p = pct(i);
          if p<30,    marks{i}='-';
          elseif p<=60,marks{i}='+';
          else        marks{i}='++'; end
        end
        figM = figure('Name','Threshold Marks','NumberTitle','off');
        imshow(gray); hold on;
        for i=1:n
          viscircles(centers(i,:),r,'EdgeColor','b');
          text(centers(i,1),centers(i,2),marks{i},'Color','r','FontSize',20,'HorizontalAlignment','center');
        end
        title('Marks: - / + / ++'); hold off;
        saveas(figM,fullfile(path,[base '_marks.png']));
        Tm = table((1:n)',marks,'VariableNames',{'Circle','Mark'});
        writetable(Tm,xlsF,'Sheet','Marks');
        
        % Update status
        set(handles.statusText, 'String', [
            'Pellicle IP Analysis completed successfully!' newline newline ...
            'Results saved to: ' path newline ...
            'Generated files:' newline ...
            '• ' base '_IP.png (annotated image)' newline ...
            '• ' base '_graph.png/.pdf (bar chart)' newline ...
            '• ' base '_marks.png (threshold marks)' newline ...
            '• ' base '_results.xlsx (detailed results)' newline newline ...
            'Ready for next operation.']);
        
    catch ME
        set(handles.statusText, 'String', ['Error in Pellicle IP Analysis: ' ME.message newline newline ...
                                          'Please check your inputs and try again.']);
        disp(getReport(ME, 'extended'));
 end
        end
        
        function runBacterialGIP(handles)
 try
        % Store the original figure handle for restoration later
        origFig = gcf;
        isOrigFigValid = ishandle(origFig);
        
        % Check if handles.statusText is still valid
        if isfield(handles, 'statusText') && ishandle(handles.statusText)
            set(handles.statusText, 'String', 'Starting BacterialG IP Analysis...');
            drawnow;
        end
        
        % This function implements the BacterialG_IP functionality directly
        % Constants
        PETRI_DISH_DIAMETER_MM = 86; % Real petri dish diameter in mm
        
        % Save the selected filepath in a global variable for later access
        global selected_image_path;
        
        % Select image
        [filename, filepath] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'});
        if isequal(filename, 0)
            if isfield(handles, 'statusText') && ishandle(handles.statusText)
                set(handles.statusText, 'String', 'BacterialG IP Analysis canceled. Ready for next operation.');
            end
            
            % Restore focus to original figure
            if isOrigFigValid && ishandle(origFig)
                figure(origFig);
            elseif isfield(handles, 'mainFig') && ishandle(handles.mainFig)
                figure(handles.mainFig);
            end
            return;
        end
        image_path = fullfile(filepath, filename);
        
        % Store the full path for saving results later
        selected_image_path = image_path;
        
        % Debug output to verify the path
        fprintf('Selected image: %s\n', image_path);
        
        img = imread(image_path);
        original_img = img;
        
        % Resize for processing if too large
        max_size = 1200;
        if max(size(img)) > max_size
            resize_factor = max_size / max(size(img));
            img = imresize(img, resize_factor);
        else
            resize_factor = 1;
        end
        
        % Convert to different color spaces for analysis
        if size(img, 3) == 3
            gray_img = rgb2gray(img);
            lab_img = rgb2lab(img);
            hsv_img = rgb2hsv(img);
            
            % Extract useful channels
            l_channel = lab_img(:,:,1);  % Lightness
            a_channel = lab_img(:,:,2);  % Green-Red
            b_channel = lab_img(:,:,3);  % Blue-Yellow
            h_channel = hsv_img(:,:,1);  % Hue
            s_channel = hsv_img(:,:,2);  % Saturation
            v_channel = hsv_img(:,:,3);  % Value
        else
            gray_img = img;
            l_channel = gray_img;
            a_channel = gray_img;
            b_channel = gray_img;
            h_channel = gray_img;
            s_channel = gray_img;
            v_channel = gray_img;
        end
        
        % Display setup - create a new figure distinct from the main GUI figure
        % Store the handle to this new figure for cleanup later
        analysisMainFig = figure('Name', 'BacterialG IP - Robust Colony Detection', 'Position', [50, 50, 1800, 800], 'Tag', 'BacterialGIP_MainFig');
        
        %% Step 1: Enhanced Petri Dish Detection
        fprintf('Detecting petri dish...\n');
        
        % Use multiple channels for dish detection
        detection_channels = {gray_img, l_channel, v_channel};
        best_circle = [];
        best_score = 0;
        
        for ch_idx = 1:length(detection_channels)
            channel = detection_channels{ch_idx};
            
            % Gaussian blur for smoother circle detection
            blurred = imgaussfilt(channel, 3);
            
            % Try different scales
            for scale = [0.4, 0.6]
                scaled_img = imresize(blurred, scale);
                
                % Enhance edges for circle detection
                edges = edge(scaled_img, 'canny', [0.05, 0.2]);
                edges = imclose(edges, strel('disk', 2));
                
                % Detect circles
                min_r = round(min(size(scaled_img)) * 0.15);
                max_r = round(min(size(scaled_img)) * 0.48);
                
                [centers, radii, metric] = imfindcircles(edges, [min_r, max_r], ...
                    'ObjectPolarity', 'bright', 'Sensitivity', 0.9, 'EdgeThreshold', 0.03);
                
                if ~isempty(centers)
                    % Scale back and evaluate
                    centers_scaled = centers / scale;
                    radii_scaled = radii / scale;
                    
                    % Score circles by size and roundness
                    for i = 1:length(radii)
                        score = metric(i) * radii_scaled(i);
                        if score > best_score
                            best_score = score;
                            best_circle = [centers_scaled(i, :), radii_scaled(i)];
                        end
                    end
                end
            end
        end
        
        % Set dish parameters
        if ~isempty(best_circle)
            dish_center = best_circle(1:2);
            dish_radius = best_circle(3);
        else
            % Manual fallback
            dish_center = [size(gray_img, 2)/2, size(gray_img, 1)/2];
            dish_radius = min(size(gray_img))/2 * 0.82;
            fprintf('Warning: Manual dish estimation used\n');
        end
        
        % Calculate scale
        pixels_per_mm = (2 * dish_radius) / PETRI_DISH_DIAMETER_MM;
        dish_area_pixels = pi * dish_radius^2;
        
        %% Step 2: Create Precise Dish Mask
        [rows, cols] = size(gray_img);
        [X, Y] = meshgrid(1:cols, 1:rows);
        
        % Create masks at different radii for analysis
        dish_mask_full = (X - dish_center(1)).^2 + (Y - dish_center(2)).^2 <= dish_radius^2;
        dish_mask_inner = (X - dish_center(1)).^2 + (Y - dish_center(2)).^2 <= (dish_radius * 0.85)^2;
        dish_mask_outer = dish_mask_full & ~((X - dish_center(1)).^2 + (Y - dish_center(2)).^2 <= (dish_radius * 0.75)^2);
        %% Step 3: Advanced Colony Detection
        fprintf('Detecting colony with multiple methods...\n');
        
        % Method 1: Intensity-based detection specifically for light-colored colonies
        fprintf('  Method 1: Intensity analysis for light colonies...\n');
        
        % Get statistics from dish edge (background reference)
        edge_pixels = gray_img(dish_mask_outer);
        background_mean = mean(edge_pixels);
        background_std = std(double(edge_pixels));
        
        % Apply mask to focus on dish interior
        masked_gray = gray_img;
        masked_gray(~dish_mask_inner) = background_mean;
        
        % Enhance contrast with CLAHE specifically tuned for light colonies
        enhanced_gray = adapthisteq(masked_gray, 'ClipLimit', 0.01, 'Distribution', 'uniform');
        
        % Get inner dish statistics
        inner_pixels = enhanced_gray(dish_mask_inner);
        inner_mean = mean(inner_pixels);
        inner_std = std(double(inner_pixels));
        
        % Create multiple binary images with different thresholds specifically for LIGHT colonies
        % For light colonies - detect pixels BRIGHTER than background
        binary1 = enhanced_gray > (inner_mean + 0.5 * inner_std);
        binary2 = enhanced_gray > (inner_mean + 0.3 * inner_std);
        
        % Adaptive thresholding to detect bright areas
        binary3 = imbinarize(enhanced_gray, 'adaptive', 'ForegroundPolarity', 'bright', 'Sensitivity', 0.6);
        
        % Method 2: Color-based detection (if RGB image)
        fprintf('  Method 2: Color analysis for white/light colonies...\n');
        binary4 = false(size(gray_img));
        binary5 = false(size(gray_img));
        
        if size(original_img, 3) == 3
            % Use L*a*b* color space for better separation
            lab_masked = lab_img;
            for ch = 1:3
                lab_ch = lab_masked(:,:,ch);
                lab_ch(~dish_mask_inner) = mean(lab_ch(dish_mask_inner));
                lab_masked(:,:,ch) = lab_ch;
            end
            
            % Specific lightness (L channel) thresholding for white colonies
            l_ch_masked = lab_masked(:,:,1);
            l_mean = mean(l_ch_masked(dish_mask_inner));
            l_std = std(double(l_ch_masked(dish_mask_inner)));
            
            % For white colonies - detect high L values (lightness)
            binary4 = l_ch_masked > (l_mean + 0.5 * l_std);
            
            % Use saturation channel from HSV - white colonies often have lower saturation
            s_masked = s_channel;
            s_masked(~dish_mask_inner) = mean(s_channel(dish_mask_inner));
            s_mean = mean(s_masked(dish_mask_inner));
            s_std = std(double(s_masked(dish_mask_inner)));
            
            % For white colonies - detect low saturation
            binary5 = s_masked < (s_mean - 0.3 * s_std);
            
            % Brightness from HSV
            v_masked = v_channel;
            v_masked(~dish_mask_inner) = mean(v_channel(dish_mask_inner));
            v_mean = mean(v_masked(dish_mask_inner));
            v_std = std(double(v_masked(dish_mask_inner)));
            
            % For white colonies - detect high brightness
            binary6 = v_masked > (v_mean + 0.5 * v_std);
        else
            binary6 = false(size(gray_img));
        end
        
        % Method 3: Specific white colony detection using local contrast
        fprintf('  Method 3: Local contrast for white colonies...\n');
        
        % Calculate local range (max-min) as a measure of contrast
        se_range = strel('disk', 7);
        local_range = rangefilt(gray_img, getnhood(se_range));
        local_range(~dish_mask_inner) = 0;
        
        % For white/translucent colonies - often have moderate local contrast
        range_mean = mean(local_range(dish_mask_inner));
        range_std = std(double(local_range(dish_mask_inner)));
        binary7 = local_range > (range_mean - 0.5 * range_std) & local_range < (range_mean + 1.5 * range_std);
        
        % Try direct Otsu thresholding - often works well for white colonies against dark medium
        level = graythresh(gray_img(dish_mask_inner));
        binary8 = imbinarize(gray_img, level + 0.1); % More sensitive to bright pixels
        binary8 = binary8 & dish_mask_inner;
        
        % Method 4: Locally adaptive processing specifically for white colonies
        fprintf('  Method 4: Multi-scale local processing...\n');
        
        % Local processing at multiple scales
        scales = [3, 7, 15];
        binary_ms = false(size(gray_img));
        
        for scale_idx = 1:length(scales)
            radius = scales(scale_idx);
            se_local = strel('disk', radius);
            
            % Local thresholding using top-hat (for brighter regions)
            tophat_img = imtophat(gray_img, se_local);
            binary_ms = binary_ms | (tophat_img > 0.1 * max(tophat_img(:)));
        end
        
        binary9 = binary_ms & dish_mask_inner;
        
        % Special processing for very light colonies (almost white/transparent)
        % Sometimes gradient magnitude works better than raw intensity
        [Gx, Gy] = imgradientxy(gray_img);
        grad_mag = imgradient(Gx, Gy);
        
        % Normalize gradient magnitude
        grad_mag = grad_mag / max(grad_mag(:));
        
        % For translucent colonies - often have higher gradients at edges
        binary10 = grad_mag > 0.1;
        binary10 = imclose(binary10, strel('disk', 2));
        binary10 = binary10 & dish_mask_inner;
        
        %% Step 4: Combine and Refine Detection Results - Tuned for light colonies
        fprintf('Combining detection methods for white/light colonies...\n');
        
        % Collect all binary results
        binaries = {binary1, binary2, binary3, binary4, binary5, binary6, binary7, binary8, binary9, binary10};
        
        % CUSTOM WEIGHTS - highly prioritizing bright/light detection methods
        weights = [0.20, 0.15, 0.20, 0.10, 0.05, 0.10, 0.05, 0.05, 0.05, 0.05];
        
        % Create weighted combination
        combined_score = zeros(size(gray_img));
        for i = 1:length(binaries)
            combined_score = combined_score + double(binaries{i}) * weights(i);
        end
        
        % Apply final threshold
        final_binary = combined_score > 0.15; % More sensitive threshold
        final_binary = final_binary & dish_mask_inner;
        
        % Advanced morphological processing
        se1 = strel('disk', 2);
        se2 = strel('disk', 4);
        
        % Clean up the binary image
        processed_binary = imopen(final_binary, se1);           % Remove small noise
        processed_binary = imclose(processed_binary, se2);      % Connect nearby regions
        processed_binary = bwareaopen(processed_binary, 100);   % Remove small objects
        processed_binary = imfill(processed_binary, 'holes');   % Fill holes
        
        % Keep largest connected component
        cc = bwconncomp(processed_binary);
        if cc.NumObjects > 1
            areas = cellfun(@numel, cc.PixelIdxList);
            [area_sorted, sort_idx] = sort(areas, 'descending');
            
            % Keep largest component, or top 2 if they're similar in size
            if length(areas) > 1 && area_sorted(2) > area_sorted(1) * 0.3
                % Keep top 2 components if second is significant
                final_colony = false(size(processed_binary));
                final_colony(cc.PixelIdxList{sort_idx(1)}) = true;
                final_colony(cc.PixelIdxList{sort_idx(2)}) = true;
            else
                % Keep only the largest
                final_colony = false(size(processed_binary));
                final_colony(cc.PixelIdxList{sort_idx(1)}) = true;
            end
        else
            final_colony = processed_binary;
        end
        
        %% Step 5: Measurement and Analysis
        colony_diameter_mm = 0;
        max_colony_diameter_mm = 0;
        coverage_ratio = 0;
        
        if any(final_colony(:))
            % Calculate coverage ratio - specifically within the petri dish area
            colony_area_pixels = sum(final_colony(:));
            dish_interior_area_pixels = sum(dish_mask_inner(:));
            coverage_ratio = (colony_area_pixels / dish_interior_area_pixels) * 100;
            
            % Get colony properties
            props = regionprops(final_colony, 'MajorAxisLength', 'MinorAxisLength', ...
                'EquivDiameter', 'Centroid', 'BoundingBox', 'Area');
            
            if ~isempty(props)
                % Find the LONGEST LINE that passes through BOTH dish center AND colony center
                
                % Get both centers
                dish_center_point = dish_center;
                colony_center = props(1).Centroid;
                
                % For cases where the colony and dish centers are very close together,
                % we need to ensure we get a proper diameter line across the colony
                if norm([colony_center(1) - dish_center_point(1), colony_center(2) - dish_center_point(2)]) < 10
                    % Centers are very close - use the maximum colony diameter at any angle
                    colony_center_effective = colony_center;
                else
                    % Use normal centers
                    colony_center_effective = colony_center;
                end
                
                % Calculate the angle of the line connecting both centers
                center_angle = atan2(colony_center_effective(2) - dish_center_point(2), ...
                                   colony_center_effective(1) - dish_center_point(1));
                
                % Create a line passing through both centers
                % This line extends in both directions to the edge of the image
                line_length = max(size(gray_img)) * 2; % Long enough to exit image
                
                % Calculate endpoints along this angle
                x1 = colony_center_effective(1) + line_length * cos(center_angle);
                y1 = colony_center_effective(2) + line_length * sin(center_angle);
                x2 = colony_center_effective(1) - line_length * cos(center_angle);
                y2 = colony_center_effective(2) - line_length * sin(center_angle);
                
                % Create a mask for this line using external function
                center_line_mask = image_analysis_module.createLineMask(colony_center_effective, [x1, y1], size(final_colony));
                center_line_mask = center_line_mask | image_analysis_module.createLineMask(colony_center_effective, [x2, y2], size(final_colony));
                
                % Find where this line intersects the colony
                center_intersection = center_line_mask & final_colony;
                
                if any(center_intersection(:))
                    % Find the two most distant points in the intersection
                    [row, col] = find(center_intersection);
                    points = [col, row];
                    
                    % Find the maximum distance between any two points
                    if size(points, 1) >= 2
                        dists = pdist2(points, points);
                        [max_center_dist, linear_idx] = max(dists(:));
                        [idx1, idx2] = ind2sub(size(dists), linear_idx);
                        center_line_points = [points(idx1,:); points(idx2,:)];
                        
                        % Convert to millimeters
                        center_line_diameter_mm = max_center_dist / pixels_per_mm;
                    else
                        center_line_diameter_mm = 0;
                        center_line_points = [colony_center_effective; colony_center_effective];
                    end
                else
                    % If no intersections found, try a different approach
                    % Try multiple angles to find the best diameter
                    num_angles = 36; % Try every 10 degrees
                    angle_step = 2*pi/num_angles;
                    max_center_dist = 0;
                    
                    for i = 1:num_angles
                        current_angle = (i-1) * angle_step;
                        
                        % Create a line at this angle from colony center
                        x1 = colony_center(1) + line_length * cos(current_angle);
                        y1 = colony_center(2) + line_length * sin(current_angle);
                        x2 = colony_center(1) - line_length * cos(current_angle);
                        y2 = colony_center(2) - line_length * sin(current_angle);
                        
                        % Create line mask and find intersection
                        line_mask = image_analysis_module.createLineMask(colony_center, [x1, y1], size(final_colony));
                        line_mask = line_mask | image_analysis_module.createLineMask(colony_center, [x2, y2], size(final_colony));
                        
                        % Check intersection
                        intersection = line_mask & final_colony;
                        
                        if any(intersection(:))
                            [row, col] = find(intersection);
                            points = [col, row];
                            
                            if size(points, 1) >= 2
                                dists = pdist2(points, points);
                                current_max = max(dists(:));
                                
                                if current_max > max_center_dist
                                    max_center_dist = current_max;
                                    [max_idx, ~] = ind2sub(size(dists), find(dists == current_max, 1));
                                    [~, opposite_idx] = max(dists(max_idx, :));
                                    center_line_points = [points(max_idx,:); points(opposite_idx,:)];
                                end
                            end
                        end
                    end
                    
                    % Convert to millimeters
                    center_line_diameter_mm = max_center_dist / pixels_per_mm;
                end
                % Now find the longest diameter through the colony center at any angle
                num_angles = 180; % Sample every 2 degrees
                angle_step = pi/num_angles; % Only need to check 0 to π
                max_diameter = 0;
                max_points = zeros(2, 2);
                
                for i = 1:num_angles
                    current_angle = (i-1) * angle_step;
                    
                    % Create a line from the colony center at this angle
                    line_length = max(size(gray_img)) * 2;
                    
                    % Calculate endpoints
                    x1 = colony_center(1) + line_length * cos(current_angle);
                    y1 = colony_center(2) + line_length * sin(current_angle);
                    x2 = colony_center(1) - line_length * cos(current_angle);
                    y2 = colony_center(2) - line_length * sin(current_angle);
                    
                    % Create a mask for this line
                    line_mask = image_analysis_module.createLineMask(colony_center, [x1, y1], size(final_colony));
                    line_mask = line_mask | image_analysis_module.createLineMask(colony_center, [x2, y2], size(final_colony));
                    
                    % Find where this line intersects the colony
                    intersection = line_mask & final_colony;
                    
                    if any(intersection(:))
                        % Find the two most distant points in the intersection
                        [row, col] = find(intersection);
                        points = [col, row];
                        
                        % Find the maximum distance between any two points
                        if size(points, 1) >= 2
                            dists = pdist2(points, points);
                            [max_dist, linear_idx] = max(dists(:));
                            
                            if max_dist > max_diameter
                                max_diameter = max_dist;
                                [idx1, idx2] = ind2sub(size(dists), linear_idx);
                                max_points = [points(idx1,:); points(idx2,:)];
                            end
                        end
                    end
                end
                
                % Convert the maximum diameter to mm
                max_colony_diameter_mm = max_diameter / pixels_per_mm;
                
                % Use the appropriate diameter as requested
                colony_diameter_mm = center_line_diameter_mm;
                max_points = center_line_points;
                
                % Find boundary for visualization
                boundary = bwboundaries(final_colony);
                if ~isempty(boundary)
                    main_boundary = boundary{1};
                end
            end
        end
        
        % Growth classification
        if coverage_ratio == 0
            growth_class = 'No Growth';
        elseif coverage_ratio < 5
            growth_class = 'Minimal';
        elseif coverage_ratio < 15
            growth_class = 'Sparse';
        elseif coverage_ratio < 35
            growth_class = 'Moderate';
        elseif coverage_ratio < 65
            growth_class = 'Dense';
        else
            growth_class = 'Very Dense';
        end
        
        % Close any existing figures first - BUT NOT the main window
        hFigs = findall(0, 'Type', 'figure');
        for i = 1:length(hFigs)
            if ~isempty(strfind(get(hFigs(i), 'Tag'), 'BacterialGIP')) && ishandle(hFigs(i))
                close(hFigs(i));
            end
        end
        
        % Create a slightly wider figure with better spacing
        % Explicitly tag it to identify it later
        resultsFig = figure('Name', 'BacterialG IP - Colony Analysis', ...
                           'Position', [50, 50, 1200, 450], ...
                           'Tag', 'BacterialGIP_ResultsFig');
        
        % 1. Original Image
        subplot(1, 4, 1);
        imshow(imresize(original_img, [size(gray_img, 1), size(gray_img, 2)]));
        title('Original Image', 'FontSize', 12, 'FontWeight', 'bold');
        
        % 2. Dish Detection
        subplot(1, 4, 2);
        imshow(imresize(original_img, [size(gray_img, 1), size(gray_img, 2)]));
        hold on;
        viscircles(dish_center, dish_radius, 'Color', 'r', 'LineWidth', 2);
        title({'Dish Detection'; sprintf('Scale: %.2f px/mm', pixels_per_mm)}, 'FontSize', 12, 'FontWeight', 'bold');
        
        % 3. Detected Colony with Diameter Measurement (ZOOMED IN on just the plate)
        subplot(1, 4, 3);
        
        % Create a cropped version of the image focused just on the plate
        % Calculate crop boundaries with a small margin around the dish
        margin = 20; % pixels
        x_min = max(1, round(dish_center(1) - dish_radius - margin));
        y_min = max(1, round(dish_center(2) - dish_radius - margin));
        x_max = min(size(gray_img, 2), round(dish_center(1) + dish_radius + margin));
        y_max = min(size(gray_img, 1), round(dish_center(2) + dish_radius + margin));
        
        % Create crop rectangle
        crop_width = x_max - x_min + 1;
        crop_height = y_max - y_min + 1;
        crop_rect = [x_min, y_min, crop_width, crop_height];
        
        % Crop the original image
        original_cropped = imcrop(imresize(original_img, [size(gray_img, 1), size(gray_img, 2)]), crop_rect);
        imshow(original_cropped);
        hold on;
        
        % Adjust coordinates to cropped image space
        dish_center_crop = [dish_center(1) - x_min, dish_center(2) - y_min];
        dish_radius_crop = dish_radius;
        
        % Draw dish outline
        viscircles(dish_center_crop, dish_radius_crop, 'Color', 'b', 'LineWidth', 1.5);
        
        % Draw colony boundary
        if exist('main_boundary', 'var')
            boundary_crop = [main_boundary(:,2) - x_min, main_boundary(:,1) - y_min];
            plot(boundary_crop(:,1), boundary_crop(:,2), 'g-', 'LineWidth', 2);
        end
        
        % Draw both centers
        plot(dish_center_crop(1), dish_center_crop(2), 'b+', 'MarkerSize', 10, 'LineWidth', 2);
        if exist('colony_center', 'var')
            colony_center_crop = [colony_center(1) - x_min, colony_center(2) - y_min];
            plot(colony_center_crop(1), colony_center_crop(2), 'g+', 'MarkerSize', 10, 'LineWidth', 2);
        end
        
        % Draw the diameter line through the colony
        if colony_diameter_mm > 0 && exist('max_points', 'var')
            max_points_crop = [max_points(:,1) - x_min, max_points(:,2) - y_min];
            plot(max_points_crop(:,1), max_points_crop(:,2), 'r-', 'LineWidth', 3);
            plot(max_points_crop(:,1), max_points_crop(:,2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        end
        
        title({'Colony with Diameter'; sprintf('%.2f mm', colony_diameter_mm)}, 'FontSize', 12, 'FontWeight', 'bold');
        
        % 4. Plate Coverage Graph
        subplot(1, 4, 4);
        if coverage_ratio > 0
            pie_data = [coverage_ratio, 100 - coverage_ratio];
            labels = {sprintf('Colony\n%.1f%%', coverage_ratio), sprintf('Empty\n%.1f%%', 100 - coverage_ratio)};
            pie(pie_data, labels);
            colormap(gca, [0.2 0.8 0.3; 0.9 0.9 0.9]);
            title({'Plate Coverage'; sprintf('%.1f%%', coverage_ratio)}, 'FontSize', 12, 'FontWeight', 'bold');
        else
            pie([100], {'No Growth Detected'});
            colormap(gca, [0.9 0.9 0.9]);
            title('No Colony Detected', 'FontSize', 12, 'FontWeight', 'bold');
        end
        
        % Add figure title
        sgtitle('Bacterial Colony Analysis', 'FontSize', 14, 'FontWeight', 'bold');
        
        % Save the processed image for return
        processed_image = getframe(gcf).cdata;
        
        % Automatically save the figure in a subfolder where the input image was selected
        try
            % Access the global variable containing the selected image path
            global selected_image_path;
            
            % Determine the directory where the selected image is located
            if isempty(selected_image_path)
                % If somehow we don't have the path, use current directory
                image_directory = pwd;
                image_filename = 'colony_analysis';
                fprintf('Warning: Could not determine original image location, using current directory.\n');
            else
                % Extract directory and filename from the full path
                [image_directory, image_filename, ~] = fileparts(selected_image_path);
                fprintf('Saving results relative to: %s\n', image_directory);
            end
            
            % Create a results subfolder in the image directory
            results_folder = fullfile(image_directory, 'BacterialG_IP_Results');
            
            % Make directory if it doesn't exist
            if ~exist(results_folder, 'dir')
                mkdir(results_folder);
                fprintf('Created results folder: %s\n', results_folder);
            end
            
            % Create filenames for the results
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            results_basename = [image_filename, '_analysis_', timestamp];
            png_filename = fullfile(results_folder, [results_basename, '.png']);
            pdf_filename = fullfile(results_folder, [results_basename, '.pdf']);
            
            % Save PNG
            saveas(gcf, png_filename);
            
            % Save PDF with proper orientation and size
            % Get current figure size
            fig_pos = get(gcf, 'Position');
            fig_width = fig_pos(3);
            fig_height = fig_pos(4);
            
            % Determine if landscape orientation is needed based on aspect ratio
            is_landscape = (fig_width > fig_height);
            
            % Set paper properties
            set(gcf, 'PaperUnits', 'inches');
            
            if is_landscape
                % Landscape mode - wider than tall
                set(gcf, 'PaperOrientation', 'landscape');
                paper_width = 11;  % Standard letter width in landscape
                paper_height = 8.5; % Standard letter height in landscape
            else
                % Portrait mode - taller than wide
                set(gcf, 'PaperOrientation', 'portrait');
                paper_width = 8.5;  % Standard letter width in portrait
                paper_height = 11;  % Standard letter height in portrait
            end
            
            % Set paper size and position
            set(gcf, 'PaperSize', [paper_width paper_height]);
            set(gcf, 'PaperPositionMode', 'manual');
            
            % Calculate margins (10% on each side)
            margin = 0.1;
            content_width = paper_width * (1 - 2*margin);
            content_height = paper_height * (1 - 2*margin);
            
            % Center content on page with margins
            set(gcf, 'PaperPosition', [
                paper_width * margin,          % Left margin
                paper_height * margin,         % Bottom margin
                content_width,                 % Content width
                content_height                 % Content height
            ]);
            
            % Export to PDF with proper orientation
            print(gcf, pdf_filename, '-dpdf', '-r300', '-bestfit');
            
            % Confirm save location
            fprintf('\n===== RESULTS SAVED =====\n');
            fprintf('Location: %s\n', results_folder);
            fprintf('Files: %s.png/pdf\n', results_basename);
            fprintf('==========================\n');
        catch ME
            % Show error
            fprintf('Error saving results: %s\n', ME.message);
            
            % Direct fallback save in current directory
            saveas(gcf, 'colony_analysis.png');
            fprintf('Saved as colony_analysis.png in current directory.\n');
        end
        
        % Console output to command window
        fprintf('\n=== FINAL RESULTS ===\n');
        fprintf('Colony diameter: %.2f mm (along line connecting centers)\n', colony_diameter_mm);
        fprintf('Maximum possible diameter: %.2f mm\n', max_colony_diameter_mm);
        fprintf('Dish coverage: %.1f%% (%s)\n', coverage_ratio, growth_class);
        fprintf('Colony area: %.2f mm²\n', colony_area_pixels / (pixels_per_mm^2));
        fprintf('Scale factor: %.2f pixels/mm\n', pixels_per_mm);
        fprintf('====================\n');
        
        % IMPORTANT: Switch focus back to the main figure before updating status
        % This ensures we don't lose the main window
        if isfield(handles, 'mainFig') && ishandle(handles.mainFig)
            figure(handles.mainFig); % Make sure the main figure is active
            
            % Update status with the results (only if we have a valid main window)
            if isfield(handles, 'statusText') && ishandle(handles.statusText)
                set(handles.statusText, 'String', sprintf(['BacterialG IP Analysis completed successfully!\n\n', ...
                    'Colony diameter: %.2f mm\n', ...
                    'Plate coverage: %.1f%%\n\n', ...
                    'Results saved in the BacterialG_IP_Results folder.'], ...
                    colony_diameter_mm, coverage_ratio));
                drawnow; % Force update of the display
            end
        end
            
    catch ME
        % Safely handle errors - ALWAYS restore focus to main window
        if isfield(handles, 'mainFig') && ishandle(handles.mainFig)
            figure(handles.mainFig); % Make sure the main figure is active
            
            if isfield(handles, 'statusText') && ishandle(handles.statusText)
                set(handles.statusText, 'String', ['Error in BacterialG IP Analysis: ' ME.message newline newline ...
                                              'Please check your inputs and try again.']);
                drawnow;
            end
        end
        fprintf('Error: %s\n', ME.message);
        disp(getReport(ME, 'extended'));
    end
    
    % Final safety measure: Make sure no cleanup affects the main window
    if isfield(handles, 'mainFig') && ishandle(handles.mainFig)
        figure(handles.mainFig);
    end
        end
        
        function mask = createLineMask(point1, point2, imageSize)
 mask = false(imageSize);
    
    % Ensure points are within image bounds
    point1 = max(min(point1, [imageSize(2), imageSize(1)]), [1, 1]);
    point2 = max(min(point2, [imageSize(2), imageSize(1)]), [1, 1]);
    
    % Draw the line using Bresenham's algorithm
    x1 = round(point1(1)); y1 = round(point1(2));
    x2 = round(point2(1)); y2 = round(point2(2));
    
    dx = abs(x2 - x1);
    dy = abs(y2 - y1);
    steep = dy > dx;
    
    if steep
        [x1, y1] = deal(y1, x1);
        [x2, y2] = deal(y2, x2);
    end
    
    if x1 > x2
        [x1, x2] = deal(x2, x1);
        [y1, y2] = deal(y2, y1);
    end
    
    dx = x2 - x1;
    dy = abs(y2 - y1);
    err = dx / 2;
    
    if y1 < y2
        ystep = 1;
    else
        ystep = -1;
    end
    
    for x = x1:x2
        if steep
            if x > 0 && x <= imageSize(1) && y1 > 0 && y1 <= imageSize(2)
                mask(x, y1) = true;
            end
        else
            if x > 0 && x <= imageSize(2) && y1 > 0 && y1 <= imageSize(1)
                mask(y1, x) = true;
            end
        end
        
        err = err - dy;
        if err < 0
            y1 = y1 + ystep;
            err = err + dx;
        end
    end
        end
        
        function runSangerWrapper(handles)
% RUNSANGERWRAPPER - Wrapper function to integrate Sanger sequence assembly into AIA GUI
    % This function safely runs the Sanger analysis while maintaining the main GUI context
    
    try
        % Store the original figure handle for restoration later
        origFig = gcf;
        isOrigFigValid = ishandle(origFig);
        
        % Update status in the main GUI if available
        if isfield(handles, 'statusText') && ishandle(handles.statusText)
            set(handles.statusText, 'String', 'Starting Sanger Sequence Assembly...');
            drawnow;
        end
        
        % Call the main Sanger GUI function
        image_analysis_module.sanger_gui();
        
        % After Sanger analysis completes, restore focus to the main GUI
        if isOrigFigValid && ishandle(origFig)
            figure(origFig);
        elseif isfield(handles, 'mainFig') && ishandle(handles.mainFig)
            figure(handles.mainFig);
        end
        
        % Update status to indicate completion
        if isfield(handles, 'statusText') && ishandle(handles.statusText)
            set(handles.statusText, 'String', [
                'Sanger Sequence Assembly completed!' newline newline ...
                'The Sanger analysis tool has finished processing.' newline ...
                'Check the generated results files for your assembled sequence.' newline newline ...
                'Ready for next operation.']);
            drawnow;
        end
        
    catch ME
        % Handle any errors that occur during Sanger analysis
        % Safely restore focus to main window
        if isfield(handles, 'mainFig') && ishandle(handles.mainFig)
            figure(handles.mainFig);
            
            if isfield(handles, 'statusText') && ishandle(handles.statusText)
                set(handles.statusText, 'String', [
                    'Error in Sanger Sequence Assembly: ' ME.message newline newline ...
                    'Please check your input files and try again.' newline ...
                    'Ensure you have valid sequence files (.seq, .fasta, .fa, .txt).' newline newline ...
                    'Ready for next operation.']);
                drawnow;
            end
        end
        
        % Display detailed error information in command window
        fprintf('Error in Sanger analysis: %s\n', ME.message);
        disp(getReport(ME, 'extended'));
    end
    
    % Final safety measure: Ensure main window remains active
    if isfield(handles, 'mainFig') && ishandle(handles.mainFig)
        figure(handles.mainFig);
    end
        end
        
        function sanger_gui()
 % SANGER_GUI - Complete Sanger sequence assembly with improved overlap detection
    % Usage: sanger_gui (no arguments needed)
    
    % Step 1: Select files
    [filenames, pathname] = uigetfile({'*.seq;*.fasta;*.fa;*.txt', 'Sequence Files'; '*.*', 'All Files'}, ...
                                     'Select Sanger Sequence Files', 'MultiSelect', 'on');
    
    if isequal(filenames, 0)
        msgbox('No files selected!', 'Info');
        return;
    end
    
    if ischar(filenames)
        filenames = {filenames};
    end
    
    % Step 2: Read sequences
    sequences = {};
    for i = 1:length(filenames)
        full_path = fullfile(pathname, filenames{i});
        raw_seq = image_analysis_module.read_seq_file(full_path);
        if ~isempty(raw_seq)
            clean_seq = image_analysis_module.clean_seq_data(raw_seq);
            sequences{end+1} = clean_seq;
        end
    end
    
    if isempty(sequences)
        msgbox('No valid sequences found!', 'Error');
        return;
    end
    
    % Step 3: Configuration window
    config_data = image_analysis_module.show_configuration_window(sequences, filenames);
    if isempty(config_data)
        return; % User cancelled
    end
    
    % Extract configuration data
    seq_names = config_data.names;
    seq_directions = config_data.directions;
    seq_positions = config_data.positions;
    min_overlap = config_data.min_overlap;
    threshold = config_data.threshold;
    
    % Step 4: Assembly (removed confirmation dialogs)
    [final_seq, info] = image_analysis_module.assemble_sequences_with_validation(sequences, seq_names, seq_directions, ...
                                                          seq_positions, min_overlap, threshold);
    
    % Step 5: Show results
    image_analysis_module.show_results_improved(final_seq, info, seq_names, seq_directions, sequences, seq_positions);
        end
        
        function config_data = show_configuration_window(sequences, filenames)
% Create configuration window
    
    n_seqs = length(sequences);
    config_data = [];
    
    % Create main configuration figure
    fig = figure('Position', [200, 200, 800, 600], 'Name', 'Sequence Configuration', ...
                'MenuBar', 'none', 'Resize', 'off', 'WindowStyle', 'modal');
    
    % Title
    uicontrol('Style', 'text', 'Position', [20, 560, 760, 30], ...
             'String', 'Configure Your Sanger Sequences', ...
             'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % Sequence configuration area
    seq_panel_height = 350;
    seq_start_y = 180;
    
    uicontrol('Style', 'text', 'Position', [20, seq_start_y + seq_panel_height + 10, 760, 20], ...
             'String', 'Sequence Information:', 'FontSize', 12, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'left');
    
    % Headers
    uicontrol('Style', 'text', 'Position', [30, seq_start_y + seq_panel_height - 15, 200, 15], ...
             'String', 'File / Sequence Name', 'FontWeight', 'bold');
    uicontrol('Style', 'text', 'Position', [250, seq_start_y + seq_panel_height - 15, 120, 15], ...
             'String', 'Direction', 'FontWeight', 'bold');
    uicontrol('Style', 'text', 'Position', [390, seq_start_y + seq_panel_height - 15, 100, 15], ...
             'String', 'Start Position', 'FontWeight', 'bold');
    uicontrol('Style', 'text', 'Position', [510, seq_start_y + seq_panel_height - 15, 80, 15], ...
             'String', 'Length (bp)', 'FontWeight', 'bold');
    uicontrol('Style', 'text', 'Position', [610, seq_start_y + seq_panel_height - 15, 150, 15], ...
             'String', 'Preview (first 30 bp)', 'FontWeight', 'bold');
    
    % Store UI handles
    name_edits = {};
    direction_popups = {};
    position_edits = {};
    
    for i = 1:n_seqs
        y_pos = seq_start_y + seq_panel_height - 50 - (i-1) * 40;
        
        % Default name
        default_name = image_analysis_module.get_default_name(filenames{i});
        
        % Sequence name edit
        name_edits{i} = uicontrol('Style', 'edit', 'Position', [30, y_pos, 200, 25], ...
                                 'String', default_name, 'FontSize', 10);
        
        % Direction popup
        direction_popups{i} = uicontrol('Style', 'popupmenu', 'Position', [250, y_pos, 120, 25], ...
                                       'String', {'Forward', 'Reverse', 'Unknown'}, ...
                                       'FontSize', 10);
        
        % Default position
        default_pos = image_analysis_module.estimate_position(default_name, 1500);
        
        % Position edit
        position_edits{i} = uicontrol('Style', 'edit', 'Position', [390, y_pos, 100, 25], ...
                                     'String', num2str(default_pos), 'FontSize', 10);
        
        % Length display
        uicontrol('Style', 'text', 'Position', [510, y_pos, 80, 25], ...
                 'String', num2str(length(sequences{i})), 'FontSize', 10, ...
                 'HorizontalAlignment', 'center');
        
        % Preview
        preview_seq = sequences{i}(1:min(30, length(sequences{i})));
        uicontrol('Style', 'text', 'Position', [610, y_pos, 150, 25], ...
                 'String', preview_seq, 'FontSize', 8, 'FontName', 'FixedWidth', ...
                 'HorizontalAlignment', 'left');
    end
    
    % Assembly parameters section
    param_y = 120;
    uicontrol('Style', 'text', 'Position', [20, param_y + 40, 200, 20], ...
             'String', 'Assembly Parameters:', 'FontSize', 12, 'FontWeight', 'bold');
    
    uicontrol('Style', 'text', 'Position', [30, param_y + 10, 150, 20], ...
             'String', 'Minimum Overlap (bp):', 'FontSize', 10);
    overlap_edit = uicontrol('Style', 'edit', 'Position', [200, param_y + 10, 80, 25], ...
                            'String', '20', 'FontSize', 10);
    
    uicontrol('Style', 'text', 'Position', [300, param_y + 10, 150, 20], ...
             'String', 'Similarity Threshold:', 'FontSize', 10);
    threshold_edit = uicontrol('Style', 'edit', 'Position', [470, param_y + 10, 80, 25], ...
                              'String', '0.85', 'FontSize', 10);
    
    % Buttons
    uicontrol('Style', 'pushbutton', 'Position', [200, 20, 100, 40], ...
             'String', 'Cancel', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Callback', @(~,~) close(fig));
    
    uicontrol('Style', 'pushbutton', 'Position', [500, 20, 100, 40], ...
             'String', 'Continue', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Callback', @(~,~) collect_config_data());
    
    % Wait for user input
    uiwait(fig);
    
    function collect_config_data()
        % Collect all configuration data
        config_data = struct();
        config_data.names = {};
        config_data.directions = {};
        config_data.positions = {};
        
        for j = 1:n_seqs
            config_data.names{j} = get(name_edits{j}, 'String');
            
            dir_val = get(direction_popups{j}, 'Value');
            dir_strings = {'forward', 'reverse', 'unknown'};
            config_data.directions{j} = dir_strings{dir_val};
            
            config_data.positions{j} = str2double(get(position_edits{j}, 'String'));
        end
        
        config_data.min_overlap = str2double(get(overlap_edit, 'String'));
        config_data.threshold = str2double(get(threshold_edit, 'String'));
        
        close(fig);
    end
        end
        
        function seq = read_seq_file(filepath)
seq = '';
    fid = fopen(filepath, 'r');
    if fid == -1, return; end
    
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            line = strtrim(line);
            if ~isempty(line) && line(1) ~= '>' && line(1) ~= ';'
                clean_line = regexprep(line, '[^ATCGRYSWKMBDHVNatcgryswkmbdhvn]', '');
                seq = [seq upper(clean_line)];
            end
        end
    end
    fclose(fid);
        end
        
        function clean_seq = clean_seq_data(seq)
window = 50;
    threshold = 0.3;
    clean_seq = seq;
    
    % Trim from end
    for i = length(seq):-window:window
        start_pos = max(1, i-window+1);
        segment = seq(start_pos:i);
        n_count = sum(segment == 'N');
        if (n_count / length(segment)) < threshold
            clean_seq = seq(1:i);
            break;
        end
    end
    
    % Trim from start
    for i = 1:window:length(clean_seq)-window
        segment = clean_seq(i:i+window-1);
        n_count = sum(segment == 'N');
        if (n_count / length(segment)) < threshold
            clean_seq = clean_seq(i:end);
            break;
        end
    end
        end
        
        function name = get_default_name(filename)
[~, name, ~] = fileparts(filename);
    
    if contains(lower(name), '16sf')
        name = 'Forward_16S';
    elseif contains(lower(name), '909r')
        name = 'Reverse_909R';
    elseif contains(lower(name), 'forward') || contains(lower(name), '_f')
        name = 'Forward';
    elseif contains(lower(name), 'reverse') || contains(lower(name), '_r')
        name = 'Reverse';
    else
        name = regexprep(name, '[^a-zA-Z0-9_]', '_');
    end
        end
        
        function pos = estimate_position(seq_name, target_length)
name_lower = lower(seq_name);
    
    if contains(name_lower, '16sf') || contains(name_lower, 'forward')
        pos = 1;
    elseif contains(name_lower, '909r') || contains(name_lower, 'reverse')
        pos = round(target_length * 0.6);
    else
        pos = 1;
    end
    
    pos = max(1, pos);
        end
        
        function [assembled_seq, assembly_info] = assemble_sequences_with_validation(sequences, names, directions, positions, min_overlap, threshold)
 % Sequence-based assembly with proper overlap detection - ENHANCED DEBUGGING
    
    n = length(sequences);
    fprintf('\n=== IMPROVED SEQUENCE ASSEMBLY ===\n');
    fprintf('Assembling %d sequences with sequence-based validation...\n', n);
    
    % DEBUG: Print input parameters
    fprintf('\n=== INPUT ANALYSIS ===\n');
    for i = 1:n
        fprintf('Sequence %d: %s\n', i, names{i});
        fprintf('  Direction: %s\n', directions{i});
        fprintf('  User Position: %d\n', positions{i});
        fprintf('  Length: %d bp\n', length(sequences{i}));
        fprintf('  Preview: %s...\n', sequences{i}(1:min(20, length(sequences{i}))));
    end
    
    if n == 1
        assembled_seq = sequences{1};
        assembly_info.method = 'single_sequence';
        assembly_info.length = length(assembled_seq);
        assembly_info.overlaps = {};
        assembly_info.coverage = 100;
        assembly_info.validated_overlaps = {};
        return;
    end
    
    % Step 1: Prepare sequences (apply reverse complement)
    processed_sequences = cell(size(sequences));
    for i = 1:n
        if strcmp(directions{i}, 'reverse')
            processed_sequences{i} = image_analysis_module.reverse_complement(sequences{i});
            fprintf('Applied reverse complement to %s\n', names{i});
        else
            processed_sequences{i} = sequences{i};
        end
    end
    
    % Step 2: Find ALL pairwise overlaps using sequence alignment
    fprintf('Finding sequence-based overlaps...\n');
    all_overlaps = image_analysis_module.find_all_sequence_overlaps(processed_sequences, names, min_overlap, threshold);
    
    % Step 3: Validate overlaps against user positions
    fprintf('Validating overlaps against user positions...\n');
    validated_overlaps = image_analysis_module.validate_overlaps_with_positions(all_overlaps, positions, directions, sequences);
    
    % Step 4: Build assembly graph and find best path
    fprintf('Building assembly from validated overlaps...\n');
    [assembled_seq, assembly_info] = image_analysis_module.build_assembly_from_overlaps(processed_sequences, names, validated_overlaps, positions, directions);
    
    % Add detailed information
    assembly_info.method = 'sequence_validated_assembly';
    assembly_info.all_overlaps = all_overlaps;
    assembly_info.validated_overlaps = validated_overlaps;
    assembly_info.sequences_used = n;
    
    fprintf('\n=== FINAL ASSEMBLY SUMMARY ===\n');
    fprintf('Assembly completed: %d bp final sequence\n', length(assembled_seq));
    fprintf('Found %d sequence-based overlaps, %d validated with positions\n', ...
           length(all_overlaps), length(validated_overlaps));
    
    % CRITICAL DEBUG: Let's check what positions we're actually using
    fprintf('\n=== POSITION VERIFICATION ===\n');
    calculated_start = inf;
    calculated_end = -inf;
    
    for i = 1:n
        pos = positions{i};
        seq_len = length(processed_sequences{i});  % Use processed sequences
        
        if strcmp(directions{i}, 'forward')
            start_pos = pos;
            end_pos = pos + seq_len - 1;
        else
            start_pos = pos - seq_len + 1;
            end_pos = pos;
        end
        
        calculated_start = min(calculated_start, start_pos);
        calculated_end = max(calculated_end, end_pos);
        
        fprintf('Seq %d (%s): pos=%d, len=%d, direction=%s -> range %d to %d\n', ...
               i, names{i}, pos, seq_len, directions{i}, start_pos, end_pos);
    end
    
    expected_length = calculated_end - calculated_start + 1;
    actual_length = length(assembled_seq);
    
    fprintf('Expected assembly: %d to %d = %d bp\n', calculated_start, calculated_end, expected_length);
    fprintf('Actual assembly: %d bp\n', actual_length);
    
    if actual_length ~= expected_length
        fprintf('⚠️  ERROR: Length mismatch! Expected %d bp, got %d bp (difference: %d bp)\n', ...
               expected_length, actual_length, actual_length - expected_length);
    else
        fprintf('✅ Length calculation is correct!\n');
    end
        end
        
        function overlaps = find_all_sequence_overlaps(sequences, names, min_overlap, threshold)
% Find overlaps using k-mer seeding and local alignment (original thorough version)
    
    overlaps = [];
    n = length(sequences);
    k = 10; % Reduced k-mer size for better sensitivity
    
    fprintf('Scanning %d sequence pairs for overlaps...\n', nchoosek(n, 2));
    
    for i = 1:n-1
        for j = i+1:n
            seq1 = sequences{i};
            seq2 = sequences{j};
            
            fprintf('  Comparing %s (%d bp) vs %s (%d bp)...\n', names{i}, length(seq1), names{j}, length(seq2));
            
            % Try all possible overlap orientations
            % 1. seq1 suffix vs seq2 prefix (seq1 followed by seq2)
            overlap1 = image_analysis_module.find_overlap_between_pair(seq1, seq2, names{i}, names{j}, i, j, k, min_overlap, threshold, 'suffix-prefix');
            
            % 2. seq2 suffix vs seq1 prefix (seq2 followed by seq1)
            overlap2 = image_analysis_module.find_overlap_between_pair(seq2, seq1, names{j}, names{i}, j, i, k, min_overlap, threshold, 'suffix-prefix');
            
            % 3. Check for complete containment (one sequence inside another)
            overlap3 = image_analysis_module.find_containment_overlap(seq1, seq2, names{i}, names{j}, i, j, min_overlap, threshold);
            overlap4 = image_analysis_module.find_containment_overlap(seq2, seq1, names{j}, names{i}, j, i, min_overlap, threshold);
            
            if ~isempty(overlap1)
                overlaps = [overlaps overlap1];
                fprintf('    → Found suffix-prefix overlap: %s→%s (%d bp, %.1f%%)\n', ...
                       names{i}, names{j}, overlap1.overlap_length, overlap1.similarity*100);
            end
            if ~isempty(overlap2)
                overlaps = [overlaps overlap2];
                fprintf('    → Found suffix-prefix overlap: %s→%s (%d bp, %.1f%%)\n', ...
                       names{j}, names{i}, overlap2.overlap_length, overlap2.similarity*100);
            end
            if ~isempty(overlap3)
                overlaps = [overlaps overlap3];
                fprintf('    → Found containment: %s contains %s\n', names{i}, names{j});
            end
            if ~isempty(overlap4)
                overlaps = [overlaps overlap4];
                fprintf('    → Found containment: %s contains %s\n', names{j}, names{i});
            end
            
            if isempty(overlap1) && isempty(overlap2) && isempty(overlap3) && isempty(overlap4)
                fprintf('    → No significant overlap found\n');
            end
        end
    end
    
    fprintf('Found %d total sequence overlaps\n', length(overlaps));
        end
        
        function overlap = find_overlap_between_pair(seq1, seq2, name1, name2, idx1, idx2, k, min_overlap, threshold, type)
% Find overlap between two sequences using sliding window approach
    
    overlap = [];
    best_similarity = 0;
    best_overlap = [];
    
    % Limit search to reasonable range
    max_overlap = min(min(length(seq1), length(seq2)), 1000);
    
    % Try different overlap lengths
    for overlap_len = min_overlap:max_overlap
        if overlap_len > length(seq1) || overlap_len > length(seq2)
            continue;
        end
        
        % Extract regions to compare
        suffix = seq1(end-overlap_len+1:end);  % End of seq1
        prefix = seq2(1:overlap_len);          % Start of seq2
        
        % Calculate similarity directly
        similarity = image_analysis_module.calculate_simple_similarity(suffix, prefix);
        
        if similarity >= threshold && similarity > best_similarity
            best_similarity = similarity;
            best_overlap = struct();
            best_overlap.seq1_name = name1;
            best_overlap.seq2_name = name2;
            best_overlap.seq1_idx = idx1;
            best_overlap.seq2_idx = idx2;
            best_overlap.type = type;
            best_overlap.overlap_length = overlap_len;
            best_overlap.seq1_region = suffix;
            best_overlap.seq2_region = prefix;
            best_overlap.aligned_seq1 = suffix;
            best_overlap.aligned_seq2 = prefix;
            best_overlap.similarity = similarity;
            best_overlap.score = similarity * overlap_len;
            best_overlap.seq1_start = length(seq1) - overlap_len + 1;
            best_overlap.seq1_end = length(seq1);
            best_overlap.seq2_start = 1;
            best_overlap.seq2_end = overlap_len;
        end
    end
    
    if ~isempty(best_overlap)
        overlap = best_overlap;
    end
        end
        
        function overlap = find_containment_overlap(seq1, seq2, name1, name2, idx1, idx2, min_overlap, threshold)
 % Check if seq2 is contained within seq1
    
    overlap = [];
    seq2_len = length(seq2);
    
    if seq2_len < min_overlap || seq2_len > length(seq1)
        return;
    end
    
    % Slide seq2 along seq1 to find best match
    best_similarity = 0;
    best_pos = 0;
    
    for pos = 1:length(seq1)-seq2_len+1
        subseq = seq1(pos:pos+seq2_len-1);
        similarity = image_analysis_module.calculate_simple_similarity(seq2, subseq);
        
        if similarity > best_similarity
            best_similarity = similarity;
            best_pos = pos;
        end
    end
    
    if best_similarity >= threshold
        overlap = struct();
        overlap.seq1_name = name1;
        overlap.seq2_name = name2;
        overlap.seq1_idx = idx1;
        overlap.seq2_idx = idx2;
        overlap.type = 'containment';
        overlap.overlap_length = seq2_len;
        overlap.seq1_region = seq1(best_pos:best_pos+seq2_len-1);
        overlap.seq2_region = seq2;
        overlap.aligned_seq1 = overlap.seq1_region;
        overlap.aligned_seq2 = seq2;
        overlap.similarity = best_similarity;
        overlap.score = best_similarity * seq2_len;
        overlap.seq1_start = best_pos;
        overlap.seq1_end = best_pos + seq2_len - 1;
        overlap.seq2_start = 1;
        overlap.seq2_end = seq2_len;
    end
        end
        
        function similarity = calculate_simple_similarity(seq1, seq2)
% Calculate similarity between two sequences of equal length (original thorough version)
    
    if length(seq1) ~= length(seq2)
        % Pad shorter sequence or trim longer one
        min_len = min(length(seq1), length(seq2));
        seq1 = seq1(1:min_len);
        seq2 = seq2(1:min_len);
    end
    
    if length(seq1) == 0
        similarity = 0;
        return;
    end
    
    matches = 0;
    total = length(seq1);
    
    for i = 1:total
        base1 = seq1(i);
        base2 = seq2(i);
        
        if base1 == base2
            matches = matches + 1;
        elseif image_analysis_module.is_compatible_base(base1, base2)
            matches = matches + 0.5; % Partial credit for compatible bases
        end
        % N bases don't contribute to similarity calculation
    end
    
    similarity = matches / total;
        end
        
        function validated_overlaps = validate_overlaps_with_positions(all_overlaps, positions, directions, original_sequences)
% Validate sequence-based overlaps against user-provided positions
    
    validated_overlaps = [];
    
    fprintf('Validating %d overlaps against user positions...\n', length(all_overlaps));
    
    for i = 1:length(all_overlaps)
        overlap = all_overlaps(i);
        
        % Get sequence indices from the overlap structure
        seq1_idx = overlap.seq1_idx;
        seq2_idx = overlap.seq2_idx;
        
        if seq1_idx > length(positions) || seq2_idx > length(positions)
            fprintf('  ERROR: Invalid sequence index in overlap\n');
            continue;
        end
        
        % Calculate expected positions based on user input
        pos1 = positions{seq1_idx};
        pos2 = positions{seq2_idx};
        len1 = length(original_sequences{seq1_idx});
        len2 = length(original_sequences{seq2_idx});
        
        % Calculate actual genomic positions for sequences
        if strcmp(directions{seq1_idx}, 'forward')
            seq1_start = pos1;
            seq1_end = pos1 + len1 - 1;
        else
            seq1_start = pos1 - len1 + 1;
            seq1_end = pos1;
        end
        
        if strcmp(directions{seq2_idx}, 'forward')
            seq2_start = pos2;
            seq2_end = pos2 + len2 - 1;
        else
            seq2_start = pos2 - len2 + 1;
            seq2_end = pos2;
        end
        
        % Check if overlap makes positional sense
        position_compatible = false;
        expected_overlap_length = 0;
        
        if strcmp(overlap.type, 'containment')
            % For containment, check if one sequence is within the range of another
            if (seq2_start >= seq1_start && seq2_end <= seq1_end) || ...
               (seq1_start >= seq2_start && seq1_end <= seq2_end)
                position_compatible = true;
                expected_overlap_length = min(len1, len2);
            end
        else
            % For suffix-prefix overlaps, check if sequences are adjacent or overlapping
            expected_overlap_start = max(seq1_start, seq2_start);
            expected_overlap_end = min(seq1_end, seq2_end);
            expected_overlap_length = max(0, expected_overlap_end - expected_overlap_start + 1);
            
            % Allow some tolerance for position estimates
            tolerance = max(50, expected_overlap_length * 0.3);
            
            if expected_overlap_length >= 10 && ...
               abs(overlap.overlap_length - expected_overlap_length) <= tolerance
                position_compatible = true;
            end
        end
        
        if position_compatible
            % Add position information to overlap
            overlap.genomic_start = max(seq1_start, seq2_start);
            overlap.genomic_end = min(seq1_end, seq2_end);
            overlap.expected_length = expected_overlap_length;
            overlap.position_validated = true;
            
            validated_overlaps = [validated_overlaps overlap];
            
            fprintf('  ✓ VALIDATED: %s vs %s (sequence: %dbp, position: %dbp, %.1f%% sim)\n', ...
                   overlap.seq1_name, overlap.seq2_name, overlap.overlap_length, ...
                   expected_overlap_length, overlap.similarity*100);
        else
            fprintf('  ✗ REJECTED: %s vs %s (sequence: %dbp, position: %dbp) - incompatible\n', ...
                   overlap.seq1_name, overlap.seq2_name, overlap.overlap_length, expected_overlap_length);
        end
    end
    
    fprintf('Validated %d overlaps out of %d candidates\n', length(validated_overlaps), length(all_overlaps));
        end
        
        function [assembled_seq, assembly_info] = build_assembly_from_overlaps(sequences, names, validated_overlaps, positions, directions)
% Build final assembly with STRICT user boundary enforcement
    
    n = length(sequences);
    assembly_info = struct();
    
    if isempty(validated_overlaps)
        fprintf('No validated overlaps found - using position-guided assembly\n');
        [assembled_seq, assembly_info] = image_analysis_module.position_guided_assembly(sequences, names, positions, directions);
        return;
    end
    
    % STRICT BOUNDARY ENFORCEMENT: Use ONLY user-provided positions
    fprintf('\n=== STRICT BOUNDARY CALCULATION ===\n');
    user_positions = cell2mat(positions);
    assembly_start = min(user_positions);
    assembly_end = max(user_positions);
    
    fprintf('User positions: %s\n', mat2str(user_positions));
    fprintf('ENFORCED assembly boundaries: %d to %d\n', assembly_start, assembly_end);
    
    % HARD CONSTRAINT: Assembly length is EXACTLY the span between min and max user positions
    assembly_length = assembly_end - assembly_start + 1;
    fprintf('ENFORCED assembly length: %d bp (no extensions allowed)\n', assembly_length);
    
    % Initialize assembly
    assembled_seq = repmat('N', 1, assembly_length);
    coverage = zeros(1, assembly_length);
    
    % Place sequences with STRICT boundary checking
    fprintf('\n=== STRICT SEQUENCE PLACEMENT ===\n');
    for i = 1:n
        user_pos = positions{i};
        processed_seq = sequences{i};
        seq_len = length(processed_seq);
        
        % STRICT: Sequence must start at user position and fit within boundaries
        start_pos = user_pos;
        end_pos = start_pos + seq_len - 1;
        
        % Check if sequence extends beyond allowed boundaries
        if end_pos > assembly_end
            fprintf('⚠️  WARNING: %s extends beyond boundary (%d > %d), will be trimmed\n', ...
                   names{i}, end_pos, assembly_end);
            end_pos = assembly_end;
            seq_len = end_pos - start_pos + 1;
        end
        
        if start_pos < assembly_start
            fprintf('⚠️  WARNING: %s starts before boundary (%d < %d), will be trimmed\n', ...
                   names{i}, start_pos, assembly_start);
            start_pos = assembly_start;
            seq_len = end_pos - start_pos + 1;
        end
        
        % Convert to array coordinates
        array_start = start_pos - assembly_start + 1;
        array_end = array_start + seq_len - 1;
        
        % SAFETY: Ensure we don't exceed array bounds
        array_start = max(1, array_start);
        array_end = min(assembly_length, array_end);
        
        fprintf('Placing %s: user_pos=%d, constrained to %d-%d, array_pos=%d-%d\n', ...
               names{i}, user_pos, start_pos, end_pos, array_start, array_end);
        
        if array_start <= array_end && seq_len > 0
            % Determine which part of the sequence to use
            seq_start = 1;
            seq_end = length(processed_seq);
            
            % Trim sequence if it was constrained
            if start_pos > user_pos
                seq_start = seq_start + (start_pos - user_pos);
            end
            if end_pos < user_pos + length(processed_seq) - 1
                seq_end = seq_end - ((user_pos + length(processed_seq) - 1) - end_pos);
            end
            
            if seq_start <= seq_end
                seq_to_place = processed_seq(seq_start:seq_end);
                
                % Place the sequence
                for j = 1:length(seq_to_place)
                    pos_in_assembly = array_start + j - 1;
                    if pos_in_assembly >= 1 && pos_in_assembly <= assembly_length
                        new_base = seq_to_place(j);
                        existing_base = assembled_seq(pos_in_assembly);
                        
                        if existing_base == 'N'
                            assembled_seq(pos_in_assembly) = new_base;
                        elseif existing_base ~= new_base
                            resolved_base = image_analysis_module.resolve_conflict_with_overlaps(existing_base, new_base, validated_overlaps, i, pos_in_assembly);
                            assembled_seq(pos_in_assembly) = resolved_base;
                        end
                        
                        coverage(pos_in_assembly) = coverage(pos_in_assembly) + 1;
                    end
                end
                
                fprintf('✅ Successfully placed %s (%d bp used)\n', names{i}, length(seq_to_place));
            end
        end
    end
    
    % Calculate statistics
    real_bases = sum(assembled_seq ~= 'N');
    assembly_coverage = (real_bases / assembly_length) * 100;
    
    assembly_info.length = length(assembled_seq);
    assembly_info.coverage = assembly_coverage;
    assembly_info.real_bases = real_bases;
    assembly_info.n_bases = assembly_length - real_bases;
    assembly_info.boundaries = [assembly_start, assembly_end];
    assembly_info.overlaps = validated_overlaps;
    assembly_info.avg_coverage = mean(coverage(coverage > 0));
    
    fprintf('\n=== FINAL ASSEMBLY (BOUNDARY ENFORCED) ===\n');
    fprintf('Final length: %d bp (EXACTLY as constrained: %d-%d)\n', ...
           length(assembled_seq), assembly_start, assembly_end);
    fprintf('Coverage: %.1f%%, Validated overlaps: %d\n', assembly_coverage, length(validated_overlaps));
    
    % VERIFICATION: This should NEVER fail now
    if length(assembled_seq) ~= assembly_length
        fprintf('🚨 IMPOSSIBLE ERROR: Length mismatch after strict enforcement!\n');
    end
    
    if length(assembled_seq) > (assembly_end - assembly_start + 1)
        fprintf('🚨 IMPOSSIBLE ERROR: Assembly exceeds user boundaries!\n');
    end
        end
        
        function original_seq = get_original_sequence_for_position(seq_idx, sequences, directions)
% Helper function to get the original sequence length for position calculations
    % This accounts for the fact that reverse sequences might have been reverse complemented
    
    % For position calculations, we always use the original sequence length
    % regardless of whether it was reverse complemented during processing
    
    % Since the sequences array here contains PROCESSED sequences,
    % we need to be careful. The length should be the same before and after
    % reverse complement, so we can just use the current length.
    original_seq = sequences{seq_idx};
        end
        
        function resolved_base = resolve_conflict_with_overlaps(base1, base2, validated_overlaps, seq_idx, position)
 % Resolve base conflicts using overlap quality information
    
    % Simple resolution for now - could be enhanced with quality scores
    if base1 == base2
        resolved_base = base1;
    elseif image_analysis_module.is_compatible_base(base1, base2)
        % Choose more specific base
        if ismember(base1, 'ATCG')
            resolved_base = base1;
        elseif ismember(base2, 'ATCG')
            resolved_base = base2;
        else
            resolved_base = base1;
        end
    else
        % For real conflicts, could use overlap quality - for now use first
        resolved_base = base1;
    end
        end
        
        function [assembled_seq, assembly_info] = position_guided_assembly(sequences, names, positions, directions)
 % Position-guided assembly with STRICT boundary enforcement
    
    fprintf('Using position-guided assembly (no validated overlaps)\n');
    
    n = length(sequences);
    
    % STRICT BOUNDARY ENFORCEMENT: Use ONLY user-provided positions
    fprintf('\n=== STRICT BOUNDARY CALCULATION ===\n');
    user_positions = cell2mat(positions);
    assembly_start = min(user_positions);
    assembly_end = max(user_positions);
    
    fprintf('User positions: %s\n', mat2str(user_positions));
    fprintf('ENFORCED assembly boundaries: %d to %d\n', assembly_start, assembly_end);
    
    % HARD CONSTRAINT: Assembly length is EXACTLY the span between min and max user positions
    assembly_length = assembly_end - assembly_start + 1;
    fprintf('ENFORCED assembly length: %d bp (no extensions allowed)\n', assembly_length);
    
    % Initialize assembly
    assembled_seq = repmat('N', 1, assembly_length);
    
    % Place sequences with STRICT boundary checking
    fprintf('\n=== STRICT SEQUENCE PLACEMENT ===\n');
    for i = 1:n
        user_pos = positions{i};
        seq = sequences{i};
        seq_len = length(seq);
        
        % STRICT: Sequence must start at user position and fit within boundaries
        start_pos = user_pos;
        end_pos = start_pos + seq_len - 1;
        
        % Check if sequence extends beyond allowed boundaries
        if end_pos > assembly_end
            fprintf('⚠️  WARNING: %s extends beyond boundary (%d > %d), will be trimmed\n', ...
                   names{i}, end_pos, assembly_end);
            end_pos = assembly_end;
            seq_len = end_pos - start_pos + 1;
        end
        
        if start_pos < assembly_start
            fprintf('⚠️  WARNING: %s starts before boundary (%d < %d), will be trimmed\n', ...
                   names{i}, start_pos, assembly_start);
            start_pos = assembly_start;
            seq_len = end_pos - start_pos + 1;
        end
        
        % Convert to array coordinates
        array_start = start_pos - assembly_start + 1;
        array_end = array_start + seq_len - 1;
        
        % SAFETY: Ensure we don't exceed array bounds
        array_start = max(1, array_start);
        array_end = min(assembly_length, array_end);
        
        fprintf('Placing %s: user_pos=%d, constrained to %d-%d, array_pos=%d-%d\n', ...
               names{i}, user_pos, start_pos, end_pos, array_start, array_end);
        
        if array_start <= array_end && seq_len > 0
            % Determine which part of the sequence to use
            seq_start = 1;
            seq_end = length(seq);
            
            % Trim sequence if it was constrained
            if start_pos > user_pos
                seq_start = seq_start + (start_pos - user_pos);
            end
            if end_pos < user_pos + length(seq) - 1
                seq_end = seq_end - ((user_pos + length(seq) - 1) - end_pos);
            end
            
            if seq_start <= seq_end
                seq_to_place = seq(seq_start:seq_end);
                
                for j = 1:length(seq_to_place)
                    pos_in_assembly = array_start + j - 1;
                    if pos_in_assembly >= 1 && pos_in_assembly <= assembly_length
                        new_base = seq_to_place(j);
                        existing_base = assembled_seq(pos_in_assembly);
                        
                        if existing_base == 'N'
                            assembled_seq(pos_in_assembly) = new_base;
                        elseif existing_base ~= new_base
                            if image_analysis_module.is_compatible_base(existing_base, new_base)
                                if ismember(existing_base, 'ATCG')
                                    assembled_seq(pos_in_assembly) = existing_base;
                                elseif ismember(new_base, 'ATCG')
                                    assembled_seq(pos_in_assembly) = new_base;
                                end
                            end
                        end
                    end
                end
                
                fprintf('✅ Successfully placed %s (%d bp used)\n', names{i}, length(seq_to_place));
            end
        end
    end
    
    % Calculate statistics
    real_bases = sum(assembled_seq ~= 'N');
    assembly_coverage = (real_bases / assembly_length) * 100;
    
    assembly_info.length = length(assembled_seq);
    assembly_info.coverage = assembly_coverage;
    assembly_info.real_bases = real_bases;
    assembly_info.n_bases = assembly_length - real_bases;
    assembly_info.boundaries = [assembly_start, assembly_end];
    assembly_info.overlaps = {};
    assembly_info.validated_overlaps = {};
    
    fprintf('\n=== FINAL ASSEMBLY (BOUNDARY ENFORCED) ===\n');
    fprintf('Final length: %d bp (EXACTLY as constrained: %d-%d)\n', ...
           length(assembled_seq), assembly_start, assembly_end);
    fprintf('Coverage: %.1f%%\n', assembly_coverage);
    
    % VERIFICATION: This should NEVER fail now
    if length(assembled_seq) ~= assembly_length
        fprintf('🚨 IMPOSSIBLE ERROR: Length mismatch after strict enforcement!\n');
    end
    
    if length(assembled_seq) > (assembly_end - assembly_start + 1)
        fprintf('🚨 IMPOSSIBLE ERROR: Assembly exceeds user boundaries!\n');
    end
        end
        
        function compatible = is_compatible_base(base1, base2)
compatible = false;
    
    compat_map = containers.Map();
    compat_map('R') = 'AG';
    compat_map('Y') = 'CT';
    compat_map('S') = 'GC';
    compat_map('W') = 'AT';
    compat_map('K') = 'GT';
    compat_map('M') = 'AC';
    compat_map('B') = 'CGT';
    compat_map('D') = 'AGT';
    compat_map('H') = 'ACT';
    compat_map('V') = 'ACG';
    
    if isKey(compat_map, base1) && contains(compat_map(base1), base2)
        compatible = true;
    elseif isKey(compat_map, base2) && contains(compat_map(base2), base1)
        compatible = true;
    end
        end
        
        function rc_seq = reverse_complement(seq)
comp_map = containers.Map({'A','T','G','C','N','R','Y','S','W','K','M','B','D','H','V'}, ...
                             {'T','A','C','G','N','Y','R','S','W','M','K','V','H','D','B'});
    
    rc_seq = '';
    for i = length(seq):-1:1
        if isKey(comp_map, seq(i))
            rc_seq = [rc_seq comp_map(seq(i))];
        else
            rc_seq = [rc_seq 'N'];
        end
    end
        end
        
        function show_results_improved(final_seq, info, names, directions, sequences, seq_positions)
% Enhanced results display with clean layout and specific buttons
    
    result_text = sprintf('=== ENHANCED ASSEMBLY RESULTS ===\n\n');
    result_text = [result_text sprintf('Assembly Method: %s\n', info.method)];
    result_text = [result_text sprintf('Final Length: %d bp (%.1f%% coverage)\n', ...
                                     length(final_seq), info.coverage)];
    result_text = [result_text sprintf('Sequences Used: %d\n', length(names))];
    
    if isfield(info, 'all_overlaps') && ~isempty(info.all_overlaps)
        result_text = [result_text sprintf('Sequence-based Overlaps Found: %d\n', length(info.all_overlaps))];
        result_text = [result_text sprintf('Position-validated Overlaps: %d\n', length(info.validated_overlaps))];
    end
    
    if isfield(info, 'real_bases')
        result_text = [result_text sprintf('Real Bases: %d (%.1f%%)\n', ...
                                         info.real_bases, (info.real_bases/length(final_seq))*100)];
        result_text = [result_text sprintf('N Bases (gaps): %d (%.1f%%)\n', ...
                                         info.n_bases, (info.n_bases/length(final_seq))*100)];
    end
    
    result_text = [result_text sprintf('\nSequence Details:\n')];
    for i = 1:length(names)
        result_text = [result_text sprintf('  %d. %s (%s, %d bp)\n', i, names{i}, directions{i}, length(sequences{i}))];
    end
    
    if isfield(info, 'validated_overlaps') && ~isempty(info.validated_overlaps)
        result_text = [result_text sprintf('\nValidated Overlaps:\n')];
        for i = 1:length(info.validated_overlaps)
            overlap = info.validated_overlaps(i);
            result_text = [result_text sprintf('  %s ↔ %s: %d bp (%.1f%% similarity)\n', ...
                                             overlap.seq1_name, overlap.seq2_name, ...
                                             overlap.overlap_length, overlap.similarity*100)];
        end
    end
    
    result_text = [result_text sprintf('\n=== SEQUENCE PREVIEW ===\n')];
    result_text = [result_text sprintf('First 100 bp:\n%s\n\n', final_seq(1:min(100,length(final_seq))))];
    if length(final_seq) > 200
        result_text = [result_text sprintf('Last 100 bp:\n%s\n', final_seq(max(1,length(final_seq)-99):end))];
    end
    
    % Create results figure with improved layout
    f = figure('Position', [200 200 1000 650], 'Name', 'Enhanced Sanger Assembly Results', ...
              'MenuBar', 'none', 'Resize', 'off');
    
    % Add main title
    uicontrol('Style', 'text', 'Position', [20, 615, 960, 25], ...
             'String', 'Enhanced Sanger Sequence Assembly Results', ...
             'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
             'BackgroundColor', [0.9, 0.95, 1]);
    
    % Text area (larger now with cleaner button layout)
    uicontrol('Style', 'text', 'String', result_text, 'Units', 'normalized', ...
              'Position', [0.02 0.18 0.96 0.75], 'HorizontalAlignment', 'left', ...
              'FontName', 'Courier', 'FontSize', 9, 'BackgroundColor', 'white', ...
              'Max', 2, 'Min', 0);
    
    % Clean button layout - improved spacing and positioning
    button_width = 0.18;
    button_height = 0.06;
    button_spacing = 0.025;
    start_x = 0.05;
    button_y = 0.08;
    
    % Close button
    uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
              'Position', [start_x, button_y, button_width, button_height], ...
              'String', 'Close', 'FontSize', 12, 'FontWeight', 'bold', ...
              'Callback', @(~,~) close(f));
    
    % Copy Sequence button
    uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
              'Position', [start_x + (button_width + button_spacing), button_y, button_width, button_height], ...
              'String', 'Copy Sequence', 'FontSize', 12, 'FontWeight', 'bold', ...
              'Callback', @(~,~) clipboard('copy', final_seq));
    
    % Complete Sequence (Save FASTA) button
    uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
              'Position', [start_x + 2*(button_width + button_spacing), button_y, button_width, button_height], ...
              'String', 'Complete Sequence', 'FontSize', 12, 'FontWeight', 'bold', ...
              'Callback', @(~,~) image_analysis_module.save_fasta_file(final_seq));
    
    % Figure 1 - Concatenation Overview
    uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
              'Position', [start_x + 3*(button_width + button_spacing), button_y, button_width, button_height], ...
              'String', 'Concatenation View', 'FontSize', 11, 'FontWeight', 'bold', ...
              'Callback', @(~,~) image_analysis_module.show_concatenation_figure(sequences, names, directions, seq_positions, info));
    
    % Add Figure 2 button if overlaps exist
    if isfield(info, 'validated_overlaps') && ~isempty(info.validated_overlaps)
        % Move buttons to accommodate 5 buttons
        button_width = 0.15;
        button_spacing = 0.035;
        start_x = 0.075;
        
        % Reposition existing buttons
        set(findobj(f, 'String', 'Close'), 'Position', [start_x, button_y, button_width, button_height]);
        set(findobj(f, 'String', 'Copy Sequence'), 'Position', [start_x + (button_width + button_spacing), button_y, button_width, button_height]);
        set(findobj(f, 'String', 'Complete Sequence'), 'Position', [start_x + 2*(button_width + button_spacing), button_y, button_width, button_height]);
        set(findobj(f, 'String', 'Concatenation View'), 'Position', [start_x + 3*(button_width + button_spacing), button_y, button_width, button_height]);
        
        % Add Figure 2 button
        uicontrol('Style', 'pushbutton', 'Units', 'normalized', ...
                  'Position', [start_x + 4*(button_width + button_spacing), button_y, button_width, button_height], ...
                  'String', 'Alignment View', 'FontSize', 11, 'FontWeight', 'bold', ...
                  'Callback', @(~,~) image_analysis_module.show_alignment_figure(sequences, names, directions, seq_positions, info));
    end
    
    % Status message (moved up and improved)
    if isfield(info, 'all_overlaps') && ~isempty(info.all_overlaps)
        status_msg = sprintf('✓ Assembly completed successfully: %d overlaps found, %d validated', ...
                           length(info.all_overlaps), length(info.validated_overlaps));
        color = [0, 0.6, 0];
        bg_color = [0.9, 1, 0.9];
    else
        status_msg = '⚠ Position-guided assembly completed (no sequence overlaps detected)';
        color = [0.8, 0.5, 0];
        bg_color = [1, 0.95, 0.9];
    end
    
    uicontrol('Style', 'text', 'Position', [20, 590, 960, 20], ...
              'String', status_msg, 'FontSize', 11, 'FontWeight', 'bold', ...
              'ForegroundColor', color, 'BackgroundColor', bg_color, ...
              'HorizontalAlignment', 'center');
        end
        
        function show_sequence_alignment_with_scrolling(ax, sequences, names, directions, seq_positions, info)
 % Enhanced alignment visualization with horizontal scrolling capability
    
    if ~isfield(info, 'validated_overlaps') || isempty(info.validated_overlaps)
        % No overlaps to show - display message
        text(ax, 0.5, 0.5, 'No validated overlaps found for detailed alignment view', ...
             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 16, 'FontWeight', 'bold', ...
             'Color', [0.6, 0.6, 0.6]);
        title(ax, 'No Sequence Overlaps Detected', 'FontSize', 14, 'FontWeight', 'bold');
        set(ax, 'XTick', [], 'YTick', []);
        return;
    end
    
    % Show the first (best) overlap in detail
    overlap = info.validated_overlaps(1);
    
    % Get the overlap sequences
    seq1_region = overlap.seq1_region;
    seq2_region = overlap.seq2_region;
    
    % Create base-by-base comparison
    overlap_length = min(length(seq1_region), length(seq2_region));
    
    % Show full sequence (no truncation for scrolling)
    seq1_display = seq1_region;
    seq2_display = seq2_region;
    display_length = overlap_length;
    
    % Set up the plot area for scrolling
    hold(ax, 'on');
    
    % Calculate positions for bases
    base_spacing = 1; % Space between bases
    y_seq1 = 3;
    y_comparison = 2;
    y_seq2 = 1;
    
    % Draw sequence 1 bases
    for i = 1:display_length
        x_pos = i * base_spacing;
        base = seq1_display(i);
        base_color = image_analysis_module.get_base_color(base);
        
        % Create colored rectangle for base
        rectangle(ax, 'Position', [x_pos-0.4, y_seq1-0.3, 0.8, 0.6], ...
                 'FaceColor', base_color, 'EdgeColor', 'black', 'LineWidth', 0.5);
        
        % Add base letter
        text(ax, x_pos, y_seq1, base, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 10, 'FontWeight', 'bold', ...
             'Color', 'white');
    end
    
    % Add sequence 1 label
    text(ax, -2, y_seq1, overlap.seq1_name, 'HorizontalAlignment', 'right', ...
         'VerticalAlignment', 'middle', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Draw comparison symbols
    for i = 1:display_length
        x_pos = i * base_spacing;
        base1 = seq1_display(i);
        base2 = seq2_display(i);
        
        if base1 == base2
            symbol = '|';  % Perfect match
            color = [0, 0.8, 0];
        elseif image_analysis_module.is_compatible_base(base1, base2)
            symbol = ':';  % Compatible
            color = [0.8, 0.6, 0];
        else
            symbol = '·';  % Mismatch
            color = [0.8, 0, 0];
        end
        
        text(ax, x_pos, y_comparison, symbol, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Color', color);
    end
    
    % Add comparison label
    text(ax, -2, y_comparison, 'Match', 'HorizontalAlignment', 'right', ...
         'VerticalAlignment', 'middle', 'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', [0.5, 0.5, 0.5]);
    
    % Draw sequence 2 bases
    for i = 1:display_length
        x_pos = i * base_spacing;
        base = seq2_display(i);
        base_color = image_analysis_module.get_base_color(base);
        
        % Create colored rectangle for base
        rectangle(ax, 'Position', [x_pos-0.4, y_seq2-0.3, 0.8, 0.6], ...
                 'FaceColor', base_color, 'EdgeColor', 'black', 'LineWidth', 0.5);
        
        % Add base letter
        text(ax, x_pos, y_seq2, base, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 10, 'FontWeight', 'bold', ...
             'Color', 'white');
    end
    
    % Add sequence 2 label
    text(ax, -2, y_seq2, overlap.seq2_name, 'HorizontalAlignment', 'right', ...
         'VerticalAlignment', 'middle', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Add position markers every 10 bases
    for i = 1:10:display_length
        x_pos = i * base_spacing;
        text(ax, x_pos, 0.2, num2str(i), 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0.5, 0.5, 0.5], ...
             'FontWeight', 'bold');
        
        % Add vertical grid line
        line(ax, [x_pos, x_pos], [0.5, 3.5], 'Color', [0.8, 0.8, 0.8], ...
             'LineStyle', '--', 'LineWidth', 0.5);
    end
    
    % Set axis properties for scrolling
    xlim(ax, [0, min(50, display_length + 5)]); % Initially show first 50 bases
    ylim(ax, [0, 4]);
    set(ax, 'YTick', []);
    xlabel(ax, 'Base Position in Overlap Region', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Calculate and display statistics
    matches = 0;
    mismatches = 0;
    compatible = 0;
    
    for i = 1:display_length
        base1 = seq1_display(i);
        base2 = seq2_display(i);
        
        if base1 == base2
            matches = matches + 1;
        elseif image_analysis_module.is_compatible_base(base1, base2)
            compatible = compatible + 1;
        else
            mismatches = mismatches + 1;
        end
    end
    
    % Title with statistics
    title_text = sprintf('%s ↔ %s Overlap: %d bp | Matches: %d (%.1f%%) | Compatible: %d (%.1f%%) | Mismatches: %d (%.1f%%)', ...
                        overlap.seq1_name, overlap.seq2_name, display_length, ...
                        matches, (matches/display_length)*100, ...
                        compatible, (compatible/display_length)*100, ...
                        mismatches, (mismatches/display_length)*100);
    title(ax, title_text, 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    % Add legend
    legend_x = display_length + 10;
    legend_bases = {'A', 'T', 'G', 'C', 'N'};
    legend_colors = {[0.8,0.1,0.1], [0.1,0.1,0.8], [0.1,0.7,0.1], [0.9,0.5,0.1], [0.5,0.5,0.5]};
    legend_names = {'Adenine', 'Thymine', 'Guanine', 'Cytosine', 'Unknown'};
    
    for i = 1:5
        y_pos = 4 - i*0.3;
        rectangle(ax, 'Position', [legend_x-0.4, y_pos-0.1, 0.8, 0.2], ...
                 'FaceColor', legend_colors{i}, 'EdgeColor', 'black');
        text(ax, legend_x, y_pos, legend_bases{i}, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 8, 'FontWeight', 'bold', 'Color', 'white');
        text(ax, legend_x + 1, y_pos, legend_names{i}, 'HorizontalAlignment', 'left', ...
             'VerticalAlignment', 'middle', 'FontSize', 9);
    end
    
    % Set full axis limits for scrolling
    set(ax, 'XLim', [0, min(50, display_length + 15)]);
    set(ax, 'XLimMode', 'manual');
    
    % Enable horizontal scrolling
    grid(ax, 'on');
    set(ax, 'GridAlpha', 0.3);
    
    hold(ax, 'off');
        end
        
        function save_fasta_file(sequence)
 % Save sequence as FASTA file
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    default_name = sprintf('assembled_sequence_%s.fasta', timestamp);
    
    [filename, pathname] = uiputfile('*.fasta', 'Save FASTA File', default_name);
    if ~isequal(filename, 0)
        full_path = fullfile(pathname, filename);
        fid = fopen(full_path, 'w');
        fprintf(fid, '>Enhanced_Assembly_%dbp_%s\n', length(sequence), timestamp);
        
        % Write in 80-character lines
        for i = 1:80:length(sequence)
            end_pos = min(i+79, length(sequence));
            fprintf(fid, '%s\n', sequence(i:end_pos));
        end
        fclose(fid);
        
        msgbox(sprintf('FASTA file saved successfully!\n%s\n\nLength: %d bp', ...
                      full_path, length(sequence)), 'File Saved');
    end
        end
        
        function show_concatenation_figure(sequences, names, directions, seq_positions, info)
% Figure 1: Show concatenation visualization only
    
    fig = figure('Position', [100, 200, 1400, 700], 'Name', 'Sequence Concatenation Overview', ...
                'MenuBar', 'figure', 'ToolBar', 'figure');
    
    % Create axes with proper positioning
    ax = axes('Position', [0.08, 0.15, 0.85, 0.75]);
    
    % Single panel for concatenation
    image_analysis_module.show_concatenation_visualization(sequences, names, directions, seq_positions, info);
    
    % Add main title
    title('Sequence Concatenation Overview - How Individual Sequences Form the Final Assembly', ...
          'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    % Add close button
    uicontrol('Style', 'pushbutton', 'Position', [650, 20, 100, 40], ...
             'String', 'Close', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Callback', @(~,~) close(fig));
        end
        
        function show_alignment_figure(sequences, names, directions, seq_positions, info)
 % Figure 2: Show alignment visualization with horizontal scrolling
    
    fig = figure('Position', [150, 150, 1400, 700], 'Name', 'Base-by-Base Sequence Alignment', ...
                'MenuBar', 'figure', 'ToolBar', 'figure');
    
    % Create scrollable panel for alignment
    main_panel = uipanel('Parent', fig, 'Position', [0.02, 0.15, 0.96, 0.8], ...
                        'BorderType', 'line', 'BackgroundColor', 'white');
    
    % Create axes within the panel
    ax = axes('Parent', main_panel, 'Position', [0.05, 0.1, 0.9, 0.8]);
    
    % Show alignment with scrolling capability
    image_analysis_module.show_sequence_alignment_with_scrolling(ax, sequences, names, directions, seq_positions, info);
    
    % Add main title
    sgtitle('Base-by-Base Sequence Alignment - Detailed Overlap Analysis', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    % Add navigation controls
    uicontrol('Style', 'text', 'Position', [50, 80, 300, 20], ...
             'String', 'Use mouse wheel or toolbar to zoom and pan horizontally', ...
             'FontSize', 10, 'HorizontalAlignment', 'left');
    
    % Add close button
    uicontrol('Style', 'pushbutton', 'Position', [650, 20, 100, 40], ...
             'String', 'Close', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Callback', @(~,~) close(fig));
    
    % Enable pan and zoom
    pan(fig, 'xon');  % Enable horizontal panning only
    zoom(fig, 'on');   % Enable zooming
        end
        
        function show_concatenation_visualization(sequences, names, directions, seq_positions, info)
% Top visualization: Show how sequences are concatenated into final assembly
    
    n_seqs = length(sequences);
    
    % Calculate assembly boundaries
    assembly_start = inf;
    assembly_end = -inf;
    
    for i = 1:n_seqs
        pos = seq_positions{i};
        seq_len = length(sequences{i});
        
        if strcmp(directions{i}, 'forward')
            start_pos = pos;
            end_pos = pos + seq_len - 1;
        else
            start_pos = pos - seq_len + 1;
            end_pos = pos;
        end
        
        assembly_start = min(assembly_start, start_pos);
        assembly_end = max(assembly_end, end_pos);
    end
    
    total_span = assembly_end - assembly_start + 1;
    
    % Define colors for sequences (distinct but not too bright)
    colors = [
        0.2, 0.4, 0.8;  % Blue
        0.8, 0.2, 0.3;  % Red  
        0.1, 0.7, 0.2;  % Green
        0.9, 0.5, 0.1;  % Orange
        0.6, 0.3, 0.8;  % Purple
        0.8, 0.7, 0.2;  % Yellow
        0.3, 0.8, 0.8   % Cyan
    ];
    
    hold on;
    
    % Draw assembly backbone
    backbone_y = n_seqs + 2;
    backbone_height = 0.3;
    rectangle('Position', [assembly_start, backbone_y - backbone_height/2, total_span, backbone_height], ...
             'FaceColor', [0.9, 0.9, 0.9], 'EdgeColor', [0.5, 0.5, 0.5], 'LineWidth', 2);
    text(assembly_start + total_span/2, backbone_y + 0.4, 'Final Assembled Sequence', ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Draw individual sequences
    for i = 1:n_seqs
        pos = seq_positions{i};
        seq_len = length(sequences{i});
        color = colors(mod(i-1, size(colors,1)) + 1, :);
        
        if strcmp(directions{i}, 'forward')
            start_pos = pos;
            end_pos = pos + seq_len - 1;
            arrow_text = '→';
        else
            start_pos = pos - seq_len + 1;
            end_pos = pos;
            arrow_text = '←';
        end
        
        y_pos = i;
        bar_height = 0.6;
        
        % Draw sequence bar
        rectangle('Position', [start_pos, y_pos - bar_height/2, seq_len, bar_height], ...
                 'FaceColor', color, 'EdgeColor', 'black', 'LineWidth', 1.5);
        
        % Add sequence label
        text(assembly_start - total_span*0.05, y_pos, sprintf('%s %s', names{i}, arrow_text), ...
             'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
             'FontSize', 11, 'FontWeight', 'bold', 'Color', color);
        
        % Add position labels
        text(start_pos, y_pos - bar_height/2 - 0.2, num2str(start_pos), ...
             'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.3, 0.3, 0.3]);
        text(end_pos, y_pos - bar_height/2 - 0.2, num2str(end_pos), ...
             'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.3, 0.3, 0.3]);
        
        % Draw connection lines to backbone
        plot([start_pos + seq_len/2, start_pos + seq_len/2], [y_pos + bar_height/2, backbone_y - backbone_height/2], ...
             '--', 'Color', color, 'LineWidth', 2);
    end
    
    % Show overlaps if they exist
    if isfield(info, 'validated_overlaps') && ~isempty(info.validated_overlaps)
        for k = 1:length(info.validated_overlaps)
            overlap = info.validated_overlaps(k);
            seq1_idx = overlap.seq1_idx;
            seq2_idx = overlap.seq2_idx;
            
            if seq1_idx <= n_seqs && seq2_idx <= n_seqs
                y1 = seq1_idx;
                y2 = seq2_idx;
                
                % Calculate overlap position
                if isfield(overlap, 'genomic_start') && isfield(overlap, 'genomic_end')
                    overlap_center = (overlap.genomic_start + overlap.genomic_end) / 2;
                else
                    overlap_center = (seq_positions{seq1_idx} + seq_positions{seq2_idx}) / 2;
                end
                
                % Draw overlap indicator
                plot([overlap_center, overlap_center], [y1, y2], '-', ...
                     'Color', [0, 0.8, 0], 'LineWidth', 4);
                
                % Add overlap label
                text(overlap_center, (y1 + y2)/2, sprintf('%dbp\n%.1f%%', ...
                     overlap.overlap_length, overlap.similarity*100), ...
                     'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                     'FontSize', 9, 'FontWeight', 'bold', 'Color', [0, 0.6, 0], ...
                     'BackgroundColor', [1, 1, 1], 'EdgeColor', [0, 0.8, 0], 'Margin', 2);
            end
        end
    end
    
    % Set axis properties
    xlim([assembly_start - total_span*0.15, assembly_end + total_span*0.05]);
    ylim([0.5, n_seqs + 2.5]);
    xlabel('Position (bp)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Sequence Concatenation Overview', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Remove y-axis ticks and add grid
    set(gca, 'YTick', []);
    grid on;
    set(gca, 'GridAlpha', 0.3);
        end
        
        function show_sequence_alignment_with_overlaps(sequences, names, directions, seq_positions, info)
% Bottom visualization: Show detailed base-by-base alignment in overlap regions
    
    if ~isfield(info, 'validated_overlaps') || isempty(info.validated_overlaps)
        % No overlaps to show - display message
        text(0.5, 0.5, 'No validated overlaps found for detailed alignment view', ...
             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'middle', 'FontSize', 14, 'FontWeight', 'bold', ...
             'Color', [0.6, 0.6, 0.6]);
        title('Sequence Alignment Details', 'FontSize', 14, 'FontWeight', 'bold');
        return;
    end
    
    % Show the first (best) overlap in detail
    overlap = info.validated_overlaps(1);
    
    % Get the overlap sequences
    seq1_region = overlap.seq1_region;
    seq2_region = overlap.seq2_region;
    
    % Create base-by-base comparison
    overlap_length = min(length(seq1_region), length(seq2_region));
    
    % Limit display to reasonable length
    max_display = 60;
    if overlap_length > max_display
        display_length = max_display;
        seq1_display = seq1_region(1:display_length);
        seq2_display = seq2_region(1:display_length);
        truncated = true;
    else
        display_length = overlap_length;
        seq1_display = seq1_region;
        seq2_display = seq2_region;
        truncated = false;
    end
    
    % Create character-by-character alignment visualization
    y_spacing = 0.15;
    x_start = 0.1;
    char_width = 0.8 / display_length;
    
    % Title
    title_text = sprintf('Base-by-Base Alignment: %s ↔ %s', overlap.seq1_name, overlap.seq2_name);
    if truncated
        title_text = [title_text sprintf(' (showing first %d of %d bp)', display_length, overlap_length)];
    end
    title(title_text, 'FontSize', 14, 'FontWeight', 'bold');
    
    % Draw sequence 1
    for i = 1:display_length
        x_pos = x_start + (i-1) * char_width;
        base = seq1_display(i);
        
        % Color code bases
        base_color = image_analysis_module.get_base_color(base);
        
        text(x_pos, 0.8, base, 'Units', 'normalized', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', base_color, ...
             'BackgroundColor', [0.95, 0.95, 0.95]);
    end
    
    % Add sequence 1 label
    text(x_start - 0.05, 0.8, overlap.seq1_name, 'Units', 'normalized', ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
         'FontSize', 12, 'FontWeight', 'bold');
    
    % Draw comparison symbols
    for i = 1:display_length
        x_pos = x_start + (i-1) * char_width;
        base1 = seq1_display(i);
        base2 = seq2_display(i);
        
        if base1 == base2
            symbol = '|';  % Perfect match
            color = [0, 0.8, 0];
        elseif image_analysis_module.is_compatible_base(base1, base2)
            symbol = ':';  % Compatible
            color = [0.8, 0.6, 0];
        else
            symbol = '·';  % Mismatch
            color = [0.8, 0, 0];
        end
        
        text(x_pos, 0.5, symbol, 'Units', 'normalized', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
             'FontSize', 14, 'FontWeight', 'bold', 'Color', color);
    end
    
    % Draw sequence 2
    for i = 1:display_length
        x_pos = x_start + (i-1) * char_width;
        base = seq2_display(i);
        
        % Color code bases
        base_color = image_analysis_module.get_base_color(base);
        
        text(x_pos, 0.2, base, 'Units', 'normalized', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', base_color, ...
             'BackgroundColor', [0.95, 0.95, 0.95]);
    end
    
    % Add sequence 2 label
    text(x_start - 0.05, 0.2, overlap.seq2_name, 'Units', 'normalized', ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
         'FontSize', 12, 'FontWeight', 'bold');
    
    % Add position numbers every 10 bases
    for i = 1:10:display_length
        x_pos = x_start + (i-1) * char_width;
        text(x_pos, 0.05, num2str(i), 'Units', 'normalized', ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
             'FontSize', 9, 'Color', [0.5, 0.5, 0.5]);
    end
    
    % Add legend and statistics
    legend_x = 0.7;
    legend_y = 0.9;
    
    % Calculate match statistics
    matches = 0;
    mismatches = 0;
    compatible = 0;
    
    for i = 1:display_length
        base1 = seq1_display(i);
        base2 = seq2_display(i);
        
        if base1 == base2
            matches = matches + 1;
        elseif image_analysis_module.is_compatible_base(base1, base2)
            compatible = compatible + 1;
        else
            mismatches = mismatches + 1;
        end
    end
    
    % Display statistics
    stats_text = sprintf('Overlap Statistics:\nMatches: %d/%d (%.1f%%)\nCompatible: %d (%.1f%%)\nMismatches: %d (%.1f%%)', ...
                        matches, display_length, (matches/display_length)*100, ...
                        compatible, (compatible/display_length)*100, ...
                        mismatches, (mismatches/display_length)*100);
    
    text(legend_x, legend_y, stats_text, 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', [0.95, 0.95, 0.95], 'EdgeColor', 'black', 'Margin', 5);
    
    % Legend for symbols
    legend_text = 'Symbols:\n| = Perfect match\n: = Compatible\n· = Mismatch';
    text(legend_x, 0.4, legend_text, 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 10, ...
         'BackgroundColor', [0.9, 0.9, 0.9], 'EdgeColor', 'black', 'Margin', 5);
    
    % Remove axis
    axis off;
        end
        
        function color = get_base_color(base)
% Return color for DNA base
    switch upper(base)
        case 'A'
            color = [0.8, 0.1, 0.1];  % Red
        case 'T'
            color = [0.1, 0.1, 0.8];  % Blue
        case 'G'
            color = [0.1, 0.7, 0.1];  % Green
        case 'C'
            color = [0.9, 0.5, 0.1];  % Orange
        case 'N'
            color = [0.5, 0.5, 0.5];  % Gray
        otherwise
            color = [0.6, 0.3, 0.8];  % Purple for ambiguous bases
    end
        end
        
        function analyze_pores_freehand_scroll()
 %% analyze_pores_freehand_scroll.m
    % Allows freehand ROI drawing for pore analysis
    % Press middle mouse (scroll) to finish each image

   %% -- User parameters --
minPoreSize = 25;  % minimum pore area in pixels

%% 1) Let user pick the folder containing the images
imageFolder = uigetdir(pwd, 'Select folder containing images');
if isequal(imageFolder,0)
    error('No folder selected. Exiting.');
end

%% 2) Create a results subfolder
outFolder = fullfile(imageFolder,'results');
if ~exist(outFolder,'dir')
    mkdir(outFolder);
end

%% 3) Find all JPEG/PNG files in the folder
files = dir(fullfile(imageFolder,'*.jp*g'));
files = [files; dir(fullfile(imageFolder,'*.png'))];  %#ok<AGROW>
n = numel(files);
if n==0
    error('No images found in %s', imageFolder);
end

%% 4) Preallocate results table
Results = table('Size',[n 4], ...
    'VariableTypes',{'string','double','double','double'}, ...
    'VariableNames',{'Image','PoreFraction','PoreCount','MeanPoreArea'});

%% 5) Process each image
for k = 1:n
    fn = files(k).name;
    Results.Image(k) = fn;

    % Read and prepare image
    Irgb = imread(fullfile(imageFolder,fn));
    I    = rgb2gray(Irgb);

    % Show image and wait for freehand ROIs
    hFig = figure('Name',['Draw ROIs on ' fn],'NumberTitle','off');
    imshow(Irgb); hold on;
    title({'Draw ROI shapes (Freehand).','Press scroll/middle mouse to finish.'});

    rois = {};
    set(hFig, 'WindowButtonDownFcn', @(src,evt)setappdata(src,'click',get(src,'SelectionType')));

    while true
        waitforbuttonpress;
        clickType = getappdata(hFig,'click');
        if strcmp(clickType, 'extend')  % scroll/middle mouse to finish
            break;
        elseif strcmp(clickType, 'normal')  % left-click to draw
            hFH = drawfreehand('Color','g');
            if ~isempty(hFH.Position)
                wait(hFH);  % let user finish adjusting
                rois{end+1} = createMask(hFH);  % save ROI mask
            end
        end
    end
    pause(0.5); close(hFig);

    % Overlay figure setup
    hOV = figure('Visible','off'); imshow(Irgb); hold on;

    % Analyze each ROI
    poreMetrics = zeros(numel(rois), 3);  % PoreFraction, PoreCount, MeanPoreArea
    for j = 1:numel(rois)
        BW_roi = rois{j};
        I_roi = I;
        I_roi(~BW_roi) = 0;

        % Segment pores: threshold, invert, cleanup
        T  = graythresh(I_roi(BW_roi));
        BW = imbinarize(I_roi, T);
        BW = imcomplement(BW);
        BW = BW & BW_roi;
        BW = bwareaopen(BW, minPoreSize);

        % Measure
        stats = regionprops(BW,'Area');
        areas = [stats.Area];
        poreMetrics(j,1) = sum(areas) / nnz(BW_roi);  % PoreFraction
        poreMetrics(j,2) = numel(areas);              % PoreCount
        poreMetrics(j,3) = mean(areas);               % MeanPoreArea

        % Overlay pore boundaries
        B = bwboundaries(BW);
        for b = 1:numel(B)
            c = B{b};
            plot(c(:,2), c(:,1), 'r', 'LineWidth', 0.5);
        end
    end

    title([fn ' - Freehand ROI analysis'],'Interpreter','none');
    saveas(hOV, fullfile(outFolder,[fn(1:end-4) '_overlay.png']));
    close(hOV);

    % Average across all ROIs
    avgM = mean(poreMetrics,1);
    Results.PoreFraction(k) = avgM(1);
    Results.PoreCount(k)    = avgM(2);
    Results.MeanPoreArea(k) = avgM(3);
end

%% 6) Summary plots
names = {files.name};
metrics = {'PoreFraction','PoreCount','MeanPoreArea'};
h = figure;
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
for i = 1:3
    ax = nexttile;
    bar(ax, Results.(metrics{i}));
    xticks(ax,1:n); xticklabels(ax,names); xtickangle(ax,45);
    ylabel(ax,metrics{i},'Interpreter','none');
    title(ax,metrics{i},'Interpreter','none');
end
saveas(h, fullfile(outFolder,'summary_metrics.png'));

%% 7) Save results
writetable(Results, fullfile(outFolder,'analysis_results.xlsx'),'Sheet','Metrics');

fprintf('Analysis complete! Results saved to:\n%s\n', outFolder);
        end
        
    end
end