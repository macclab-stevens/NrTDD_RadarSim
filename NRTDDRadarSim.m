%% Plug Custom Channel into Wireless Network Simulator
% This example shows you how to plug a custom channel into the wireless network 
% simulator by using 5G Toolbox™ and the Communications Toolbox™ Wireless Network 
% Simulation Library.
% 
% Using this example, you can: 
% # Create and configure a 5G network with new radio (NR) base station (gNB) 
% and user equipment (UE) nodes.
% # Establish a connection between the gNB and UE nodes.
% # Create a custom channel, and plug it into the wireless network simulator.
% # Simulate a 5G network, and retrieve the statistics of the gNB and UE nodes. 
% Check if the Communications Toolbox Wireless Network Simulation Library support 
% package is installed. If the support package is not installed, MATLAB® returns 
% an error with a link to download and install the support package.

%To create the logger reference:
global L
logFileName = 'log.txt';
fid = fopen(logFileName,'w');
fclose(fid);
L = log4m.getLogger(logFileName);
L.setCommandWindowLevel(L.ALL);
L.setLogLevel(L.ALL);
L.debug('main','Start Logging');
L.error('exampleFunction','An error occurred');



% Create a wireless network simulator.
wirelessnetworkSupportPackageCheck %%Check its installed 
networkSimulator = wirelessNetworkSimulator.init;

% Create a gNB node with these specifications. 
% * Position — [100 –100 0]
% * Channel bandwidth — 20 MHz
% * Subcarrier spacing — 30 KHz 
% * Duplex mode — Time division duplex
% https://www.mathworks.com/help/5g/ref/nrgnb.html
PhyAbst = "None";
gnb = nrGNB( ...
    Name='gNB_1',...
    Position=[-100 100 0], ...
    NoiseFigure = 6, ...
    ReceiveGain = 6, ...
    NumTransmitAntennas = 1,...
    NumReceiveAntennas = 1,...
    TransmitPower = 34, ...
    PHYAbstractionMethod=PhyAbst,...
    DuplexMode="TDD", ...
    CarrierFrequency = 3.5e9,...
    ChannelBandwidth=20e6, ...
    SubcarrierSpacing=15e3, ...
    NumResourceBlocks = 16 ....
    );
 
% Create two UE nodes, specifying their positions in Cartesian coordinates.

ue1 = nrUE(Position=[100 100 0],PHYAbstractionMethod=PhyAbst); % In Cartesian x, y, and z coordinates.
ue2 = nrUE(Position=[5000 100 0],PHYAbstractionMethod=PhyAbst);
ueNodes = [ue1 ue2];
%%
% Configure a scheduler at the gNB with a maximum number of two users per transmission 
% time interval (TTI).
simParameters.NumUEs = 2;
simParameters.NumRBs = 16;
scheduler = hCustomScheduler(simParameters);
addScheduler(gNB.MACEntity,scheduler);
configureScheduler(gNB,Scheduler="RoundRobin",ResourceAllocationType=0);
% configureScheduler(gnb,MaxNumUsersPerTTI=2)


% Initialize the properties that are specific to this custom scheduling strategy
%% 
% Connect the UE nodes to the gNB node and enable full-buffer traffic.
connectUE(gnb,ueNodes,FullBufferTraffic="on")
 
% Add the nodes to the network simulator.
addNodes(networkSimulator,gnb)
addNodes(networkSimulator,ueNodes)

% Add the custom channel to the wireless network simulator.
addChannelModel(networkSimulator,@addImpairment);

% Specify the simulation time in second
simulationTime = 0.050;
%%
%Radar
global Radar
Radar.PRI_Hz = 640; %Hz
Radar.PRI = 1/ Radar.PRI_Hz;
Radar.PW = 40e-6; %uS NOTE PW MUST be less than slot duration. 15kHz < 1ms, 30kHz < 0.5ms, etc...
Radar.StartOffset = 990e-6;
Radar.Starts = [Radar.StartOffset];
while Radar.Starts(end) < simulationTime
    Radar.Starts(end + 1) = Radar.Starts(end) + Radar.PRI;
end
disp(Radar.Starts)
% Calling a Python script using the system command
pythonCommand = strcat("../5GTDD-Radar-Visualizer/5G_TDD_Visualizer.py"," -f 'InterferenceVisual.jpg'"," -i")
[status, cmdout] = system(pythonCommand);
disp(cmdout)

%% 
% Run the simulation for the specified simulation time.

run(networkSimulator,simulationTime)
%% 
% Obtain the statistics for the gNB and UE nodes.

gnbStats = statistics(gnb)
gnbStats.MAC
ueStats = statistics(ueNodes)

%% 
% Follow these steps to create a custom channel that models NR path loss for 
% an urban macrocell scenario.
% * Create a custom function with this syntax: |rxData = customFcnName(rxInfo,txData)|. 
% The |rxInfo| input (a structure) is the receiver node information, and the |txData| 
% input (a structure) specifies the transmitted packets. The simulator automatically 
% passes information about the receiver node and the packets transmitted by a 
% transmitter node as inputs to the custom function. For more information about 
% this, see the <docid:comm_ref#mw_17054773-3d39-4e39-8566-5fac05380a1e addChannelModel> 
% object function.
% * Use the <docid:5g_ref#mw_object_nrPathLossConfig |nrPathLossConfig|> object 
% to set path loss configuration parameters for an urban macrocell scenario. 
% * Calculate path loss between the base station and UE nodes using the <docid:5g_ref#mw_function_nrPathLoss 
% |nrPathLoss|> function. Specify carrier frequency, line of sight (LOS) between 
% the gNB and UE nodes, and the transmitter and receiver positions.
% * Apply path loss to the transmitted packets.

function outputData = addImpairment(rxInfo,txData)
% fprintf("add Impairment\n")
% Set path loss configuration parameters
pathLossConfig = nrPathLossConfig;
pathLossConfig.Scenario = "UMa";      % Urban macrocell
pathLossConfig.EnvironmentHeight = 1; % Average height of the environment in UMa/UMi
los = 1;                              % Assume LOS between the gNB and UE nodes

outputData = txData;

% Calculate path loss
pathLoss = nrPathLoss(pathLossConfig,txData.CenterFrequency,los, ...
    txData.TransmitterPosition',rxInfo.Position');
outputData.Power = outputData.Power - pathLoss;
% outputData.Data = zeros(size(outputData.Data))
% Set default values for channel parameters

outputData.Metadata.Channel.PathGains = ...
    permute(ones(outputData.NumTransmitAntennas,rxInfo.NumReceiveAntennas),[3 4 1 2])/ ...
    sqrt(rxInfo.NumReceiveAntennas);
outputData.Metadata.Channel.PathFilters = 1;
outputData.Metadata.Channel.SampleTimes = 0;

if outputData.Abstraction == 0                             % Full physical layer processing
    % outputData.Data = outputData.Data.*db2mag(-pathLoss);
    outputData.Data = outputData.Data.*db2mag(-pathLoss);
    numTxAnts = outputData.NumTransmitAntennas;
    numRxAnts = rxInfo.NumReceiveAntennas;
    H = fft(eye(max([numTxAnts numRxAnts])));
    H = H(1:numTxAnts,1:numRxAnts);
    H = H/norm(H);
    outputData.Data = txData.Data*H; % Apply channel to the waveform
    % outputData.Data = ones(size(outputData.Data));
    % disp(outputData)
    
    fprintf("\n %d %d %f %f %f \n",outputData.Type,outputData.TransmitterID,outputData.StartTime,outputData.Duration,outputData.SampleRate)



    %%Null IQ Data that lines up with the radar pulses
    outputData = applyRadar(outputData);


end
end


function Data = applyRadar(Data)
    global Radar;
    global L;
    
    L.debug('applyRadar',"applyRadarFunctionStart")

    for i = 1:length(Radar.Starts)
        startTime = Radar.Starts(i);
        %if radar start value is between start_time and start_time+duration
        if startTime>=Data.StartTime & startTime <= (Data.StartTime+Data.Duration)
            L.debug('applyRadar',"PulseHead inside slot")
            L.debug('applyRadar',strcat("Radar Index ",string(Radar.Starts(i))));
            L.debug('applyRadar',strcat("Radar Pulse at T ",string(startTime)," between",string(Data.StartTime)," - ",string(Data.StartTime+Data.Duration) ))
            numSamples = length(Data.Data);
            sampleDur = Data.Duration/numSamples;
            L.debug('applyRadar', strcat(string(numSamples)," samples over ",string(Data.Duration),"(s). 1 Sample = ",string(sampleDur),"(s)"))
            Radar.PWsamples = int64(Radar.PW/sampleDur);
            L.debug('applyRadar',strcat("Radar PulseWidth is ",string(Radar.PW)," (s) or ",string(Radar.PWsamples)," samples" ) );
            Radar.SampleStart = int64((Radar.Starts(i) - Data.StartTime)/sampleDur);
            Radar.SampleStop = Radar.SampleStart+Radar.PWsamples;
            if Radar.SampleStop > numSamples; Radar.SampleStop = numSamples;end %only apply IQ inside the slot. 
            L.debug('applyRadar',strcat("Radar Pulse starts at sample index: ",string(Radar.SampleStart) ) );
            L.debug('applyRadar',strcat("IQ Data will be ones() from sample index ",string(Radar.SampleStart)," to ",string(Radar.SampleStop), " [",string(Radar.SampleStop-Radar.SampleStart),"] samples" )  );
            x = complex(ones(1,Radar.PWsamples),0);
            %DataPoints
            Data.Data(Radar.SampleStart:Radar.SampleStart+Radar.PWsamples-1) = x;
        end
        %if PulseHead NOT inside the slot, but PulseTail (+PW) is...
        if not(startTime>=Data.StartTime & startTime <= (Data.StartTime+Data.Duration)) & (startTime+Radar.PW>=Data.StartTime & startTime+Radar.PW <= (Data.StartTime+Data.Duration))
            L.debug('applyRadar',"PulseTail inside slot")
            pulseTailOverlap = startTime+Radar.PW-Data.StartTime;
            pulseTailSamples = int64(pulseTailOverlap/(Data.Duration/length(Data.Data)));
            L.debug('applyRadar',strcat("Pulse Tail is over by ",string(pulseTailOverlap)," (s) or ",string(pulseTailSamples)," samples"))
            L.debug('applyRadar',strcat("IQ Data will be ones() from sample index: ",string(1)," to ",string(pulseTailSamples)))
            x = complex(ones(1,pulseTailSamples),0);
            Data.Data(1:pulseTailSamples) = x;

        end
    end
    fprintf("-- \n")
end 