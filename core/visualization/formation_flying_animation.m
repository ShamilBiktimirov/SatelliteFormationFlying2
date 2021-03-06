function formation_flying_animation(t_vec, rv_orb, rv_orb_required, Formation_state_matrix, formation, build_reference_trajectories_flag, VideoHeader)
    
    ox = [zeros(3,1),[1500;0;0]];
    oy = [zeros(3,1),[0;1500;0]];
    oz = [zeros(3,1),[0;0;1500]];

    %% add legend
    fig = figure('Color','w');
    subplot(1,2,1);
    plot3(rv_orb(1,1,1), rv_orb(2,1,1), rv_orb(3,1,1), 'ok', 'MarkerSize', 1);
     
    hold on;
%     plot3(ox(1,:), ox(2,:), ox(3,:), 'Color', '#D95319', 'LineWidth', 1);
%     hold on;
%     plot3(oy(1,:), oy(2,:), oy(3,:),'Color', '#77AC30', 'LineWidth', 1);
%     hold on;
%     plot3(oz(1,:), oz(2,:), oz(3,:), 'Color', '#0072BD', 'LineWidth', 1);

    xlabel('x, m');
    ylabel('y, m');
    zlabel('z, m');
    xlim([-10000 10000]);
    ylim([-10000 10000]);
    zlim([-10000 10000]);
    pbaspect([1 1 1]);
    title('Orbital reference frame');
    view(135,45);
    hold on;
    grid on;
    
    subplot(1,2,2);
    plot3(rv_orb(1,1,1), rv_orb(2,1,1), rv_orb(3,1,1), 'ok', 'MarkerSize', 1);
    hold on;
%     plot3(ox(1,:), ox(2,:), ox(3,:), 'Color', '#D95319', 'LineWidth', 1);
%     hold on;
%     plot3(oy(1,:), oy(2,:), oy(3,:),'Color', '#77AC30', 'LineWidth', 1);
%     hold on;
%     plot3(oz(1,:), oz(2,:), oz(3,:), 'Color', '#0072BD', 'LineWidth', 1);
    xlabel('x, m');
    ylabel('y, m');
    xlim([-10000 10000]);
    ylim([-10000 10000]);
    hold on;
    axis square;
    title('Image projection onto the horizontal plane');
    set(get(gca,'title'),'Position',[0 12200 0]);
    view(180,-90);
    grid on;
    
    step = 1;
    T_event = Formation_state_matrix(:,1:2);   
     for i = 1:size(rv_orb,3)/step
        subplot(1,2,1);
        a = plot3(rv_orb(1,2:end,i*step), rv_orb(2,2:end,i*step), rv_orb(3,2:end,i*step), 'sk', 'MarkerSize', 4);
        if build_reference_trajectories_flag == 1
            b = plot3(rv_orb_required(1,2:end,i*step), rv_orb_required(2,2:end,i*step), rv_orb_required(3,2:end,i*step), '+r', 'MarkerSize', 2);
        end
        legend([a, b], 'current position', 'required position');
        subplot(1,2,2);
        c = plot3(rv_orb(1,2:end,i*step),rv_orb(2,2:end,i*step), rv_orb(3,2:end,i*step), 'sk', 'MarkerSize', 4);
        if build_reference_trajectories_flag == 1
            d = plot3(rv_orb_required(1,2:end,i*step), rv_orb_required(2,2:end,i*step), rv_orb_required(3,2:end,i*step), '+r', 'MarkerSize', 2);
        end
        
        drawnow;
        T = t_vec(i*step);
        q = (T_event(:,1)/60 < T & T < T_event(:,2)/60);
        [~,index] = max(q);
        current_state = Formation_state_matrix(index,3);
        if current_state == 1
            current_state = 'Reconfiguration';
            speed = 'Playback speed x1000';
        elseif current_state == 2
            current_state = 'Maintenance' ;
            speed = 'Playback speed x2000';
        elseif current_state == 3
            current_state = 'Standby (demo)';
            speed = 'Playback speed x100';
        end
        formatout = 'dd-mmm-yyyy HH:MM:SS';
        info = {['Local Time (UTC+3): ' datestr(minutes(T) + formation.orbit_epoch, formatout)],...
                ['Control regime: ' current_state],...
                speed};
        an = annotation('textbox',[0.2 0.025 0.6 0.15], 'String', info, 'FitBoxToText', 'off', 'HorizontalAlignment', 'center'); 

    %   Take a Snapshot
        movieVector(i) = getframe(fig);   %manually specify getframe region    

        delete(a);
        delete(c);
        if build_reference_trajectories_flag == 1
            delete(b);
            delete(d);
        end
        delete(an);
    end
      
    myWriter = VideoWriter(VideoHeader,'MPEG-4');   %create an .mp4 file
    myWriter.FrameRate = 24; %

    %   Open the VideoWriter object, write the movie, and close the file
    open(myWriter);
    writeVideo(myWriter, movieVector);
    close(myWriter); 
end   