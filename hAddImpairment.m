function outputData = hAddImpairment(rxInfo,txData)
fprintf("add Impairment\n")
% Set path loss configuration parameters
pathLossConfig = nrPathLossConfig;
pathLossConfig.Scenario = "UMa";      % Urban macrocell
pathLossConfig.EnvironmentHeight = 1; % Average height of the environment in UMa/UMi
los = 1;                              % Assume LOS between the gNB and UE nodes

outputData = txData

% Calculate path loss
pathLoss = 1e3*nrPathLoss(pathLossConfig,txData.CenterFrequency,los, ...
    txData.TransmitterPosition',rxInfo.Position');
outputData.Power = outputData.Power - pathLoss;

% Set default values for channel parameters

outputData.Metadata.Channel.PathGains = ...
    permute(ones(outputData.NumTransmitAntennas,rxInfo.NumReceiveAntennas),[3 4 1 2])/ ...
    sqrt(rxInfo.NumReceiveAntennas);
outputData.Metadata.Channel.PathFilters = 1;
outputData.Metadata.Channel.SampleTimes = 0;
fprintf("DataSize %d\n",size(outputData.Data))
% fprintf("Data %d\n",outputData);
outputData
if outputData.Abstraction == 0                             % Full physical layer processing
    % outputData.Data = outputData.Data.*db2mag(-pathLoss);
    outputData.Data = outputData.Data.*db2mag(-pathLoss);
    numTxAnts = outputData.NumTransmitAntennas;
    numRxAnts = rxInfo.NumReceiveAntennas;
    H = fft(eye(max([numTxAnts numRxAnts])));
    H = H(1:numTxAnts,1:numRxAnts);
    H = H/norm(H);
    outputData.Data = txData.Data*H;                      % Apply channel to the waveform
end
end