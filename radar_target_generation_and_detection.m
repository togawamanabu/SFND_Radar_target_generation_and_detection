clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

range_resolution = 1;
max_range = 200;
max_velocity = 100;

speed_of_light = 3e8;
%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant

target_position = 100;
target_velocity = -10;
 
%% FMCW Waveform Generation

% *%TODO* :
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.

Bsweep = speed_of_light / (2 * range_resolution);
Tchirp = (5.5 * 2 * max_range) / speed_of_light;
Slope = Bsweep / Tchirp;

%Operating carrier frequency of Radar 
fc= 77e9;             %carrier freq

                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

for i=1:length(t)        
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    
    r_t(i) = target_position + (t(i) * target_velocity);
    td(i) = (2 * r_t(i)) / speed_of_light;
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
 
    Tx(i) = cos(2*pi*( fc*(t(i)) + (0.5 * Slope * t(i)^2)));
    Rx(i) = cos(2*pi*( fc*(t(i)-td(i)) + ( 0.5 * Slope * (t(i)-td(i))^2)));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i).*Rx(i);
    
end

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.

Mix = reshape(Mix, [Nr, Nd]);

 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.

signal_fft1 = fft(Mix, Nr);
signal_fft1 = signal_fft1./Nr;

 % *%TODO* :
% Take the absolute value of FFT output

signal_fft1 = abs(signal_fft1);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.

signal_fft1 = signal_fft1(1:(Nr/2));

%plotting the range
figure ('Name','Range from First FFT')
% subplot(2,1,1)

% *%TODO* :
% plot FFT output 
plot(signal_fft1);
axis ([0 200 0 1]);
ylabel('Amplitude');
xlabel('range(m)');


%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
signal_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
signal_fft2 = signal_fft2(1:Nr/2,1:Nd);
signal_fft2 = fftshift (signal_fft2);
RDM = abs(signal_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
training_range = 10;
training_doppler = 10;


% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation

guard_range = 3;
guard_doppler = 3;

% *%TODO* :
% offset the threshold by SNR value in dB

offset = 1;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
%noise_level = zeros(1,1);


% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR


RDM = RDM/max(max(RDM));

for i = training_range + guard_range + 1:(Nr/2)-(guard_range+training_range)
    for j = training_doppler+guard_doppler+1:Nd-(guard_doppler+training_doppler)
        
        noise_level = zeros(1,1);
                
        for p = i-(training_range+guard_range) : i+(training_range+guard_range)
            for q = j-(training_doppler+guard_doppler) : j+(training_doppler+guard_doppler)
                if (abs(i-p) > guard_range || abs(j-q) > guard_doppler)
                    noise_level = noise_level + db2pow(RDM(p,q));
                end
            end
        end
        
        % Calculate threshould from noise average then add the offset
        threshold = pow2db(noise_level/(2*(training_doppler+guard_doppler+1)*2*(training_range+guard_range+1)-(guard_range*guard_doppler)-1));
        threshold = threshold + offset;
        CUT = RDM(i,j);
        
        if (CUT < threshold)
            RDM(i,j) = 0;
        else
            RDM(i,j) = 1;
        end
        
    end
end



% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 
 
[h, w] =  size(RDM); 

for i = 1:h
    for j = 1:w
        if(RDM(i,j) ~= 0 && RDM(i,j) ~= 1)
            RDM(i,j) = 0;
        end
    end
end


% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure,surf(doppler_axis,range_axis,RDM);
colorbar;
title('CFAR RDM');
xlabel('Speed');
ylabel('Range');
zlabel('Amplitude')
