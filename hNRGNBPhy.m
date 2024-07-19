classdef hNRGNBPhy < hNRPhyInterface
    %hNRGNBPhy 5G NR Phy Tx and Rx processing chains at gNB
    %   The class implements the Phy Tx and Rx processing chains of 5G NR
    %   at gNB. It also implements the interfaces for information exchange
    %   between Phy and higher layers. It supports transmission of physical
    %   downlink shared channel (PDSCH) along with its demodulation
    %   reference signals (DM-RS), and channel state information reference
    %   signals (CSI-RS). It only supports reception of physical uplink
    %   shared channel (PUSCH) along with its DM-RS. gNB is assumed to
    %   serve a single cell. A single bandwidth part is assumed to cover
    %   the entire carrier bandwidth. Note that setCarrierInformation and 
    %   setCellConfig need to be called on the created class object before
    %   using it.
    %
    %   hNRGNBPhy methods:
    %       hNRGNBPhy               - Construct a gNB Phy object
    %       run                     - Run the gNB Phy layer operations
    %       setCarrierInformation   - Set the carrier configuration
    %       enablePacketLogging     - Enable packet logging
    %       registerMACInterfaceFcn - Register MAC interface functions at 
    %                                 Phy, for sending information to MAC
    %       registerInBandTxFcn     - Register callback for transmission 
    %                                 on PDSCH
    %       txDataRequest           - Tx request from MAC to Phy for 
    %                                 starting PDSCH transmission
    %       dlControlRequest        - Downlink control (non-data) transmission 
    %                                 request from MAC to Phy
    %       rxDataRequest           - Rx request from MAC to Phy for 
    %                                 starting PUSCH reception
    %       phyTx                   - Physical layer processing and 
    %                                 transmission
    %       storeReception          - Receive the incoming waveform and add
    %                                 it to the reception buffer
    %       phyRx                   - Physical layer reception and sending 
    %                                 of decoded information to MAC layer
    % 
    %   Example:
    %   % Generate a hNRGNBPhy object. Configure the carrier and cell 
    %   % properties using setCarrierInformation and setCellConfig methods,
    %   respectively
    %
    %   phyParam = struct();
    %   phyParam.NumUEs = 1;
    %   phyParam.SCS = 15;
    %   phyParam.NumRBs = 52;
    %   phyParam.GNBTxPower = 29;
    %   phyParam.GNBRxGain = 11;
    %   phyParam.GNBRxBufferSize = 1;
    %   phyParam.ULCarrierFreq = 2.1e9;
    %
    %   % Configure the uplink channel model
    %   channel = nrCDLChannel;
    %   channel.DelayProfile = 'CDL-C';
    %   channel.DelaySpread = 300e-9;
    %   channel.CarrierFrequency = phyParam.ULCarrierFreq;
    %   channel.TransmitAntennaArray.Size = [1 1 1 1 1];
    %   channel.ReceiveAntennaArray.Size = [1 1 1 1 1];
    %   waveformInfo = nrOFDMInfo(phyParam.NumRBs, phyParam.SCS);
    %   channel.SampleRate = waveformInfo.SampleRate;
    %   channelModelUL = channel;
    %
    %   phy = hNRGNBPhy(phyParam);
    %
    %   carrierParam = struct();
    %   carrierParam.SubcarrierSpacing = phyParam.SCS;
    %   carrierParam.NRBsUL = phyParam.NumRBs;
    %   carrierParam.NRBsDL = phyParam.NumRBs;
    %   carrierParam.DLFreq = phyParam.ULCarrierFreq;
    %   setCarrierInformation(phy, carrierParam);
    %
    %   cellParam.NCellID = 1;
    %   cellParam.DuplexMode = 0;
    %   setCellConfig(phy, cellParam);
    %
    %   See also hNRPhyInterface
    
    %   Copyright 2020-2023 The MathWorks, Inc.

    properties
        %ULBlkErr Uplink block error information
        % It is an array of size N-by-2 where N is the number of UEs,
        % columns 1 and 2 contains the number of erroneously received
        % packets and total received packets, respectively
        ULBlkErr
    end
    
    properties (Access = private)
        %UEs RNTIs in the cell
        UEs
        
        %DLSCHEncoders Downlink shared channel (DL-SCH) encoder system objects for the UEs
        % Vector of length equal to the number of UEs in the cell. Each
        % element is an object of type nrDLSCH
        DLSCHEncoders
        
        %ULSCHDecoders Uplink shared channel (UL-SCH) decoder system objects for the UEs
        % Vector of length equal to the number of UEs in the cell. Each
        % element is an object of type nrULSCHDecoder
        ULSCHDecoders
        
        %WaveformInfoDL Downlink waveform information
        WaveformInfoDL
        
        %WaveformInfoUL Uplink waveform information
        WaveformInfoUL
        
        %TxAntPanel Tx antenna panel geometry
        % It is an array of the form [M, N, P, Mg, Ng] where M and N are 
        % the number of rows and columns in the antenna array, P is the 
        % number of polarizations (1 or 2), Mg and Ng are the number of row
        % and column array panels, respectively
        TxAntPanel

        %RxAntPanel Rx antenna panel geometry
        % It is an array of the form [M, N, P, Mg, Ng] where M and N are 
        % the number of rows and columns in the antenna array, P is the 
        % number of polarizations (1 or 2), Mg and Ng are the number of row
        % and column array panels, respectively
        RxAntPanel

        %NumTxAnts Number of transmit antennas
        NumTxAnts (1, 1) {mustBeMember(NumTxAnts, [1,2,4,8,16,32,64,128,256,512,1024])} = 1

        %NumRxAnts Number of receive antennas
        NumRxAnts (1, 1) {mustBeMember(NumRxAnts, [1,2,4,8,16,32,64,128,256,512,1024])} = 1

        %BeamWeightTable Digital beamforming weights table
        % It is a matrix of size M-by-N where M is equal to the number of
        % transmit antennas and N is the number of beam directions. Each
        % column corresponds to the beam weight used to steer the dowlink
        % transmission in a particular direction.
        BeamWeightTable

        %TxPower Tx power in dBm
        TxPower(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 29;
        
        %RxGain Rx antenna gain in dBi
        RxGain(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 11;
        
        %CSIRSPDU CSI-RS information PDU sent by MAC for the current slot
        % It is an object of type nrCSIRSConfig containing the
        % configuration of CSI-RS to be sent in current slot. If empty,
        % then CSI-RS is not scheduled for the current slot
        CSIRSPDU = {}
        
        %SRSPDU SRS information PDUs sent by MAC for the reception of SRS in the current slot
        % It is an array of objects of type nrSRSConfig. Each element
        % corresponds to an SRS configuration which is used to receive the
        % SRS. If empty, then no SRS is scheduled to be received in the current slot
        SRSPDU = {}

        %PDSCHPDU PDSCH information sent by MAC for the current slot
        % It is an array of objects of type hNRPDSCHInfo. An object at
        % index 'i' contains the information required by Phy to transmit a
        % MAC PDU stored at index 'i' of object property 'MacPDU'
        PDSCHPDU = {}
        
        %MacPDU PDUs sent by MAC which are scheduled to be sent in the current slot
        % It is an array of downlink MAC PDUs to be sent in the current
        % slot. Each object in the array corresponds to one object in
        % object property PDSCHPDU
        MacPDU = {}

        %ChannelModel Information about the propagation channel model
        % It is a cell array of length equal to the number of UEs. The
        % array contains objects of type nrCDLChannel, if the channel model
        % type is specified as 'CDL', otherwise empty. An object at index
        % 'i' models the channel between the gNB and UE with RNTI 'i'
        ChannelModel
        
        %MaxChannelDelay Maximum delay introduced by multipath components and implementation delays
        % It is an array of length equal to the number of UEs. Each element
        % at index 'i' corresponds to maximum channel delay between the gNB
        % and UE with RNTI 'i'
        MaxChannelDelay
        
        %TimingOffset Receiver timing offset
        % Receiver timing offset used for practical synchronization. It is
        % an array of length equal to the number of UEs. Each element at
        % index 'i' corresponds to the timing offset experienced during
        % reception of waveform from UE with RNTI 'i'
        TimingOffset
        
        %NoiseFigure Noise figure at the receiver
        NoiseFigure = 6;
        
        %SINRvsCQI SINR to CQI mapping
        % SINRTable is a vector of 16 SINR values in dB, each corresponding to a
        % CQI value
        SINRTable

        %RxBuffer Reception buffer object to store received waveforms
        RxBuffer

        %SRSIndicationFcn Function handle to send the measured UL channel quality to MAC
        SRSIndicationFcn
        
        %RankIndicator UL Rank to calculate precoding matrix and CQI
        % Vector of length 'N' where N is number of UEs. Value at index 'i'
        % contains UL rank of UE with RNTI 'i'
        RankIndicator

        %SRSSubbandSize Subband size for SRS measurement
        SRSSubbandSize = 4

        %AntNoiseTemperature Antenna temperature at node in Kelvin
        % It is used for thermal noise calculation
        AntNoiseTemperature = 290

        %PacketLogger Contains handle of the packet capture (PCAP) object
        PacketLogger
        
        %PacketMetaData Contains the information required for logging MAC packets into PCAP file
        PacketMetaData

        %RVSequence Redundancy version sequence
        RVSequence = [0 3 2 1]

        %NextSRSRxTime Next SRS reception time in nanoseconds
        NextSRSRxTime = -1
    end
    
    methods
        function obj = hNRGNBPhy(param)
            %hNRGNBPhy Construct a gNB Phy object
            %   OBJ = hNRGNBPHY(numUEs) constructs a gNB Phy object. It
            %   also creates the context of DL-SCH encoders system objects
            %   and UL-SCH decoders system objects for all the UEs.
            %
            %   PARAM is structure with the fields:
            %
            %       NumUEs           - Number of UEs in the cell
            %       SCS              - Subcarrier spacing
            %       NumRBs           - Number of resource blocks
            %       GNBTxPower       - Tx Power in dBm
            %       GNBRxGain        - Receiver antenna gain at gNB in dBi
            %       GNBRxBufferSize  - Maximum number of waveforms to be stored
            %       ULCarrierFreq    - Uplink carrier frequency in Hz
            %       ChannelModel     - Propagation channel model between the
            %                          gNB and UEs in the uplink direction.
            %                          In case of CDL channel, it contains
            %                          a cell array of length equal to NumUEs.
            %                          Each element of the cell array is an
            %                          object of type nrCDLChannel. Default
            %                          value is empty.
            %       GNBTxAnts        - Number of GNB Tx antennas
            %       GNBRxAnts        - Number of GNB Rx antennas
            %       UETxAnts         - Number of Tx antennas on UEs. Vector of length 'N' where N is number of UEs.
            %                          Value at index 'i' contains Tx antennas at UE with RNTI 'i'
            %       UERxAnts         - Number of Rx antennas on UEs. Vector of length 'N' where N is number of UEs.
            %                          Value at index 'i' contains Rx antennas at UE with RNTI 'i'
            %       ULRankIndicator  - UL Rank to calculate precoding
            %                          matrix and CQI. Vector of length 'N'
            %                          where N is number of UEs. Value at
            %                          index 'i' contains UL rank of UE
            %                          with RNTI 'i'
            %       SRSSubbandSize   - Subband size for SRS measurements
            %       UplinkSINR90pc   - SINR to CQI look up table. An array of
            %                          16 SINR values correspond to 16 CQI
            %                          values (0 to 15). The look up table
            %                          contains the CQI resulting in a
            %                          maximum of 0.1 BLER for the
            %                          corresponding SINR.
            %       BeamWeightTable - It is a matrix of size M-by-N where M is equal to the number of
            %                          transmit antennas and N is the number of beam directions. Each
            %                          column corresponds to the beam weight used to steer the dowlink
            %                          transmission in a particular direction.

            % Validate the number of UEs
            validateattributes(param.NumUEs, {'numeric'}, {'nonempty', 'integer', 'scalar', '>', 0, '<=', 65519}, 'param.NumUEs', 'NumUEs')
            
            obj.UEs = 1:param.NumUEs;
            
            % Create DL-SCH encoder system objects for the UEs
            obj.DLSCHEncoders = cell(param.NumUEs, 1);
            for i=1:param.NumUEs
                obj.DLSCHEncoders{i} = nrDLSCH;
                obj.DLSCHEncoders{i}.MultipleHARQProcesses = true;
            end
            
            % Create UL-SCH decoder system objects for the UEs
            obj.ULSCHDecoders = cell(param.NumUEs, 1);
            for i=1:param.NumUEs
                obj.ULSCHDecoders{i} = nrULSCHDecoder;
                obj.ULSCHDecoders{i}.MultipleHARQProcesses = true;
                obj.ULSCHDecoders{i}.LDPCDecodingAlgorithm = 'Normalized min-sum';
                obj.ULSCHDecoders{i}.MaximumLDPCIterationCount = 6;
            end
            
            % Set the number of erroneous packets and the total number of
            % packets received from each UE to zero
            obj.ULBlkErr = zeros(param.NumUEs, 2);
            
            % Set Tx power in dBm
            if isfield(param, 'GNBTxPower')
                obj.TxPower = param.GNBTxPower;
            end
            % Set Rx antenna gain in dBi
            if isfield(param, 'GNBRxGain')
                obj.RxGain = param.GNBRxGain;
            end
            
            % Set SINR vs CQI lookup table
            if isfield(param, 'UplinkSINR90pc')
                obj.SINRTable = param.UplinkSINR90pc;
            else
                obj.SINRTable = [-5.46 -0.46 4.54 9.05 11.54 14.04 15.54 18.04 ...
                    20.04 22.43 24.93 25.43 27.43 30.43 33.43];
            end

            % Set SRS subband size
            if isfield(param, 'SRSSubbandSize')
                validateattributes(param.SRSSubbandSize, {'numeric'}, ...
                    {'integer', 'scalar', '>' 0, '<=', param.NumRBs}, 'param.SRSSubbandSize', 'SRSSubbandSize')
                obj.SRSSubbandSize =  param.SRSSubbandSize;
            end
            
            % Initialize timing offsets to 0
            obj.TimingOffset = zeros(1, param.NumUEs);

            if isfield(param, 'GNBTxAnts')
                obj.NumTxAnts = param.GNBTxAnts;
            end
            if isfield(param, 'GNBRxAnts')
                obj.NumRxAnts = param.GNBRxAnts;
            end
            if ~isfield(param, 'UETxAnts')
                param.UETxAnts = ones(1, param.NumUEs);
            % Validate the number of transmitter antennas on UEs
            elseif any(~ismember(param.UETxAnts, [1,2,4,8,16]))
                error('nr5g:hNRGNBPhy:InvalidAntennaSize',...
                    'Number of UE Tx antennas must be a member of [1,2,4,8,16].');
            end
            if ~isfield(param, 'UERxAnts')
                param.UERxAnts = ones(1, param.NumUEs);
            % Validate the number of receiver antennas on UEs
            elseif any(~ismember(param.UERxAnts, [1,2,4,8,16]))                
                error('nr5g:hNRGNBPhy:InvalidAntennaSize',...
                    'Number of UE Rx antennas must be a member of [1,2,4,8,16].');
            end

            if isfield(param, 'BeamWeightTable')
                obj.BeamWeightTable = param.BeamWeightTable;
            end

            if isfield(param, 'ULRankIndicator')
                validateattributes(param.ULRankIndicator, {'numeric'}, ...
                    {'vector', 'integer', 'numel', param.NumUEs, '>=', 1, '<=', 4}, 'param.ULRankIndicator', 'ULRankIndicator')
                if nnz(param.ULRankIndicator > min(obj.NumRxAnts, param.UETxAnts))
                    error('nr5g:hNRGNBPhy:InvalidRankIndicatorValue',...
                        'UL rank indicator must be less than min(GNBRxAnts, UETxAnts)')
                end
                obj.RankIndicator = param.ULRankIndicator;
            else
                obj.RankIndicator = ones(1, param.NumUEs);
            end

            % Initialize the ChannelModel and MaxChannelDelay properties
            obj.ChannelModel = cell(1, param.NumUEs);
            obj.MaxChannelDelay = zeros(1, param.NumUEs);

            if isfield(param, 'ChannelModel')
                obj.ChannelModel = param.ChannelModel;
                for ueIdx = 1:param.NumUEs
                    chInfo = info(obj.ChannelModel{ueIdx});
                    obj.MaxChannelDelay(ueIdx) = chInfo.MaximumChannelDelay;
                end
            end
            
            % Set receiver noise figure
            if isfield(param, 'NoiseFigure')
                obj.NoiseFigure = param.NoiseFigure;
            end
            
            obj.SRSPDU = cell(10*(param.SCS/15)*14, 1); % Create the context for all the symbols in the frame
            % Create reception buffer object
            if isfield(param, 'GNBRxBufferSize')
                obj.RxBuffer = hNRPhyRxBuffer('BufferSize', param.GNBRxBufferSize, 'NRxAnts', obj.NumRxAnts);
            else
                obj.RxBuffer = hNRPhyRxBuffer('NRxAnts', obj.NumRxAnts);
            end

            % Set RV sequence
            if isfield(param, 'RVSequence')
                obj.RVSequence = param.RVSequence; 
            end
            % Validate the flag to enable/disable HARQ
            if isfield(param, 'EnableHARQ')
                % To support true/false
                validateattributes(param.EnableHARQ, {'logical', 'numeric'}, {'nonempty', 'integer', 'scalar'}, 'param.EnableHARQ', 'EnableHARQ')
                if ~param.EnableHARQ
                    % No retransmissions
                    obj.RVSequence = 0;
                end
            end
        end
        
        function nextInvokeTime = run(obj, currentTime, packets)
            %run Run the gNB Phy layer operations and return the next invoke
            %time (in nanoseconds)
            %   NEXTINVOKETIME = run(OBJ, CURRENTTIME, PACKETS) runs the
            %   Phy layer operations and returns the next invoke time (in
            %   nanoseconds).
            %
            %   NEXTINVOKETIME is the next invoke time (in nanoseconds) for
            %   PHY.
            %
            %   CURRENTTIME is the current time (in nanoseconds).
            %
            %   PACKETS are the received packets from other nodes.

            if currentTime > obj.LastRunTime
                symEndTimes = obj.CarrierInformation.SymbolTimings;
                slotDuration = obj.CarrierInformation.SlotDuration; % In nanoseconds

                % Find the current AFN
                obj.AFN = floor(currentTime/obj.FrameDurationInNS);
                % Current slot number in 10 ms frame
                obj.CurrSlot = mod(floor(currentTime/slotDuration), obj.CarrierInformation.SlotsPerFrame);
                % Find the duration completed in the current slot
                durationCompletedInCurrSlot = mod(currentTime, slotDuration);
                % Find the current symbol in the current slot
                obj.CurrSymbol = find(durationCompletedInCurrSlot < symEndTimes, 1) - 1;
            end

            % Phy processing and transmission of PDSCH (along with its
            % DM-RS) and CSI-RS. It is assumed that MAC has already loaded
            % the Phy Tx context for anything scheduled to be transmitted
            % at the current symbol
            phyTx(obj, currentTime);

            % Store the received packet
            for pktIdx = 1:numel(packets)
                if ~isfield(packets{pktIdx}, 'PacketType')
                    storeReception(obj, packets{pktIdx}, currentTime);
                end
            end

            % Phy reception of PUSCH and sending decoded information to
            % MAC. Receive the PUSCHs which ended in the last symbol.
            % Reception as well as processing is done in the symbol after
            % the last symbol in PUSCH duration (till then the packets are
            % queued in Rx buffer). Phy calculates the last symbol of PUSCH
            % duration based on 'rxDataRequest' call from MAC (which comes
            % at the first symbol of PUSCH Rx time) and the PUSCH duration
            phyRx(obj, currentTime);

            % Return the next invoke time for PHY
            nextInvokeTime = getNextInvokeTime(obj, currentTime);
            % Update the last run time
            obj.LastRunTime = currentTime;
        end
        
        function setCarrierInformation(obj, carrierInformation)
            %setCarrierInformation Set the carrier configuration
            %   setCarrierInformation(OBJ, CARRIERINFORMATION) sets the
            %   carrier configuration, CARRIERINFORMATION.
            %   CARRIERINFORMATION is a structure including the following
            %   fields:
            %       SubcarrierSpacing  - Sub carrier spacing used. Assuming
            %                            single bandwidth part in the whole
            %                            carrier
            %       NRBsDL             - Downlink bandwidth in terms of
            %                            number of resource blocks
            %       NRBsUL             - Uplink bandwidth in terms of
            %                            number of resource blocks
            %       DLBandwidth        - Downlink bandwidth in Hz
            %       ULBandwidth        - Uplink bandwidth in Hz
            %       DLFreq             - Downlink carrier frequency in Hz
            %       ULFreq             - Uplink carrier frequency in Hz
            
            setCarrierInformation@hNRPhyInterface(obj, carrierInformation);
            
            % Initialize data Rx context
            obj.DataRxContext = cell(obj.CarrierInformation.SymbolsPerFrame, 1);
            % Set waveform properties
            setWaveformProperties(obj, obj.CarrierInformation);
        end
        
        function enablePacketLogging(obj, fileName)
            %enablePacketLogging Enable packet logging
            %
            % FILENAME - Name of the PCAP file

            % Create packet logging object
            obj.PacketLogger = nrPCAPWriter(FileName=fileName, FileExtension='pcap');
            % Define the packet informtion structure
            obj.PacketMetaData = struct('RadioType',[],'RNTIType',[],'RNTI',[], ...
                'HARQID',[],'SystemFrameNumber',[],'SlotNumber',[],'LinkDir',[]);
            if obj.CellConfig.DuplexMode % Radio type
                obj.PacketMetaData.RadioType = obj.PacketLogger.RadioTDD;
            else
                obj.PacketMetaData.RadioType = obj.PacketLogger.RadioFDD;
            end
            obj.PacketMetaData.RNTIType = obj.PacketLogger.CellRNTI;
        end
        
        function registerMACInterfaceFcn(obj, sendMACPDUFcn, sendULChannelQualityFcn)
            %registerMACInterfaceFcn Register MAC interface functions at Phy, for sending information to MAC
            %   registerMACInterfaceFcn(OBJ, SENDMACPDUFCN,
            %   SENDULCHANNELQUALITYFCN) registers the callback function to
            %   send decoded MAC PDUs and measured UL channel quality to
            %   MAC.
            %
            %   SENDMACPDUFCN Function handle provided by MAC to Phy for
            %   sending PDUs to MAC.
            %   SENDULCHANNELQUALITYFCN Function handle provided by MAC to Phy for
            %   sending the measured UL channel quality (measured on SRS).
            
            obj.RxIndicationFcn = sendMACPDUFcn;
            obj.SRSIndicationFcn = sendULChannelQualityFcn;
        end
        
        function registerInBandTxFcn(obj, sendPacketFcn)
            %registerInBandTxFcn Register function handle for transmission
            %
            %   SENDPACKETFCN Function handle provided by packet
            %   distribution object for packet transmission
            
            obj.SendPacketFcn = sendPacketFcn;
        end
        
        function txDataRequest(obj, pdschInfo, macPDU, timingInfo)
            %txDataRequest Tx request from MAC to Phy for starting PDSCH transmission
            %  txDataRequest(OBJ, PDSCHINFO, MACPDU, TIMINGINFO) sets the
            %  Tx context to indicate PDSCH transmission at the CURRENT
            %  TIME.
            %
            %  PDSCHInfo is an object of type hNRPDSCHInfo, sent by MAC. It
            %  contains the information required by the Phy for the
            %  transmission.
            %
            %  MACPDU is the downlink MAC PDU sent by MAC for transmission.
            %
            %  TIMINGINFO is a structure that contains the following
            %  fields.
            %     CurrSlot   - Current slot number in a 10 millisecond frame
            %     CurrSymbol - Current symblo number in the current slot
            %     Timestamp - Transmission start timestamp in nanoseconds.

            symbolNumFrame = pdschInfo.NSlot * 14 + pdschInfo.PDSCHConfig.SymbolAllocation(1);
            obj.DataTxTime(symbolNumFrame+1) = timingInfo.Timestamp;

            % Update the Tx context. There can be multiple simultaneous
            % PDSCH transmissions for different UEs
            obj.MacPDU{end+1} = macPDU;
            obj.PDSCHPDU{end+1} = pdschInfo;
        end
        
        function dlControlRequest(obj, pduType, dlControlPDU, ~)
            %dlControlRequest Downlink control (non-data) transmission request from MAC to Phy
            %   dlControlRequest(OBJ, PDUTYPES, DLCONTROLPDUS) is a request from
            %   MAC for downlink transmission. MAC sends it at the start of
            %   a DL slot for all the scheduled non-data DL transmission in
            %   the slot (Data i.e. PDSCH is sent by MAC using
            %   txDataRequest interface of this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only packet
            %   type 0 (CSI-RS) is supported.
            %
            %   DLCONTROLPDU is an array of DL control information PDUs. Each PDU
            %   is stored at the index corresponding to its type in
            %   PDUTYPE. Currently supported CSI-RS information PDU is an object of
            %   type nrCSIRSConfig.
            
            % Update the Tx context
            obj.CSIRSPDU = cell(1, length(dlControlPDU));
            numCSIRS = 0; % Counter containing the number of CSI-RS PDUs
            for i = 1:length(pduType)
                switch pduType(i)
                    case obj.CSIRSPDUType
                        numCSIRS = numCSIRS + 1;
                        obj.CSIRSPDU{numCSIRS} = dlControlPDU{i};
                end
            end
            obj.CSIRSPDU = obj.CSIRSPDU(1:numCSIRS);
        end
        
        function ulControlRequest(obj, pduType, ulControlPDU, timingInfo)
            %ulControlRequest Uplink control (non-data) reception request from MAC to Phy
            %   ulControlRequest(OBJ, PDUTYPE, ULCONTROLPDU, RXSTARTTIME)
            %   is a request from MAC for uplink reception. MAC sends it at
            %   the start of a UL slot for all the scheduled non-data UL
            %   receptions in the slot (Data i.e. PUSCH rx request is sent
            %   by MAC using rxDataRequest interface of this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only packet
            %   type 1 (SRS) is supported.
            %
            %   ULCONTROLPDU is an array of UL control information PDUs. Each PDU
            %   is stored at the index corresponding to its type in
            %   PDUTYPE. Currently supported SRS information PDU is an object of
            %   type nrSRSConfig.
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     CurrSlot   - Current slot number in a 10 millisecond frame
            %     CurrSymbol - Current symblo number in the current slot
            %     Timestamp - Reception start timestamp in nanoseconds

            % Update the Rx context
            for i = 1:length(pduType)
                switch pduType(i)
                    case obj.SRSPDUType
                        % SRS would be read at the end of the current slot
                        currSlot = mod(timingInfo.CurrSlot, obj.CarrierInformation.SlotsPerSubframe*10);
                        rxSymbolFrame = (currSlot+1) * 14;
                        obj.SRSPDU{rxSymbolFrame}{end+1} = ulControlPDU{i};
                        obj.NextSRSRxTime = timingInfo.Timestamp + obj.CarrierInformation.SlotDuration; % In nanoseconds
                end
            end
        end
        
        function rxDataRequest(obj, puschInfo, timingInfo)
            %rxDataRequest Rx request from MAC to Phy for starting PUSCH reception
            %   rxDataRequest(OBJ, PUSCHINFO, RXSTARTTIME) is a request to
            %   start PUSCH reception. It starts a timer for PUSCH end time
            %   (which on triggering receives the complete PUSCH). The Phy
            %   expects the MAC to send this request at the start of
            %   reception time.
            %
            %   PUSCHInfo is an object of type hNRPUSCHInfo. It contains
            %   the information required by the Phy for the reception.
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     Slot      - Current slot number in a 10 millisecond frame
            %     Symbol    - Current symblo number in the current slot
            %     Timestamp - Reception start timestamp in nanoseconds.

            puschStartSym = puschInfo.PUSCHConfig.SymbolAllocation(1);
            symbolNumFrame = puschInfo.NSlot*14 + puschStartSym; % PUSCH Rx start symbol number w.r.t start of 10 ms frame
            
            % PUSCH to be read at the end of last symbol in PUSCH reception
            numPUSCHSym =  puschInfo.PUSCHConfig.SymbolAllocation(2);
            puschRxSymbolFrame = mod(symbolNumFrame + numPUSCHSym, obj.CarrierInformation.SymbolsPerFrame+1);
           
            symDur = obj.CarrierInformation.SymbolDurations; % In nanoseconds
            startSymbolIdx = puschStartSym + 1;
            endSymbolIdx = puschStartSym + numPUSCHSym;

            % Add the PUSCH Rx information at the index corresponding to
            % the symbol where PUSCH Rx ends
            obj.DataRxContext{puschRxSymbolFrame}{end+1} = puschInfo;
            % Store data reception time (in nanoseconds) information
            obj.DataRxTime(puschRxSymbolFrame) = timingInfo.Timestamp + ...
                sum(symDur(startSymbolIdx:endSymbolIdx));
        end
        
        function phyTx(obj, currentTime)
            %phyTx Physical layer processing and transmission
            %
            % CURRENTTIME - Current time in nanoseconds

            if isempty(obj.PDSCHPDU) && isempty(obj.CSIRSPDU)
                return; % No transmission (PDSCH or CSI-RS) is scheduled to start at the current symbol
            end
            
            % Calculate Tx waveform length in symbols
            numTxSymbols = 0;
            % To account for consecutive symbols in CDM pattern
            additionalCSIRSSyms = [0 0 0 0 1 0 1 1 0 1 1 1 1 1 3 1 1 3];
            for idx = 1:length(obj.CSIRSPDU)
                % If the CSIRSPDU contains a CSI-RS resource set with
                % multiple CSI-RS resources
                if length(obj.CSIRSPDU{idx}{2}) > 1
                    csirsLen = max(cell2mat(obj.CSIRSPDU{idx}{1}.SymbolLocations) + additionalCSIRSSyms(obj.CSIRSPDU{idx}{1}.RowNumber)) + 1;
                else
                    % Transmit any CSI-RS scheduled in the slot at the slot start
                    csirsLen = max(obj.CSIRSPDU{idx}{1}.SymbolLocations) + 1 + additionalCSIRSSyms(obj.CSIRSPDU{idx}{1}.RowNumber);
                end
                if csirsLen > numTxSymbols
                    numTxSymbols = csirsLen;
                end
            end

            % Among all the PDSCHs scheduled to be transmitted now, get
            % the duration in symbols of the PDSCH which spans maximum
            % number of symbols
            for i = 1:length(obj.PDSCHPDU)
                pdschLen = obj.PDSCHPDU{i}.PDSCHConfig.SymbolAllocation(2);
                if(pdschLen > numTxSymbols)
                    numTxSymbols = pdschLen;
                end
            end
           
            % Initialize Tx grid
            txGrid = zeros(obj.CarrierInformation.NRBsDL*12, obj.WaveformInfoDL.SymbolsPerSlot, obj.NumTxAnts);
           
            % Set carrier configuration object
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsDL;
            carrier.NSlot = obj.CurrSlot;
            carrier.NFrame = obj.AFN;
            
            % Fill CSI-RS in the grid
            for idx = 1:length(obj.CSIRSPDU)
                if length(obj.CSIRSPDU{idx}{2}) > 1
                     % CSI-RS resource for downlink beam sweeping
                    beamIndex = obj.CSIRSPDU{idx}{2};
                    csirs = obj.CSIRSPDU{idx}{1};
                    ports = csirs.NumCSIRSPorts(1);
                    csirsSym = nrCSIRS(carrier,csirs,'OutputResourceFormat','cell');
                    csirsInd = nrCSIRSIndices(carrier,csirs,'OutputResourceFormat','cell');
                    for resIdx = 1:length(csirs.RowNumber)
                        % Initialize the carrier resource grid for one slot and map NZP-CSI-RS symbols onto
                        % the grid
                        resourceGrid = nrResourceGrid(carrier,ports);
                        resourceGrid(csirsInd{resIdx}) = csirsSym{resIdx};
                        reshapedSymb = reshape(resourceGrid,[],ports);

                        % Apply the digital beamforming
                        bfSym = reshapedSymb * obj.BeamWeightTable(:, beamIndex(resIdx))';
                        txGrid = txGrid + reshape(bfSym,size(txGrid));
                    end
                elseif length(obj.CSIRSPDU{idx}{2}) == 1
                    % CSI-RS for downlink channel measurements
                    csirsInd = nrCSIRSIndices(carrier, obj.CSIRSPDU{idx}{1});
                    csirsSym = nrCSIRS(carrier, obj.CSIRSPDU{idx}{1});
                    beamIndex = obj.CSIRSPDU{idx}{2};
                    % Place the CSI-RS in the Tx grid
                    ports = obj.CSIRSPDU{idx}{1}.NumCSIRSPorts;
                    resourceGrid = nrResourceGrid(carrier,ports);
                    resourceGrid(csirsInd) = csirsSym;
                    reshapedSymb = reshape(resourceGrid,[],ports);
                    % Apply digital beamforming
                    bfSym = reshapedSymb * repmat(obj.BeamWeightTable(:, beamIndex)', ports, 1);
                    txGrid = txGrid + reshape(bfSym,size(txGrid));
                else % if beamforming is disabled
                    csirsInd = nrCSIRSIndices(carrier, obj.CSIRSPDU{idx}{1});
                    csirsSym = nrCSIRS(carrier, obj.CSIRSPDU{idx}{1});
                    txGrid(csirsInd) = csirsSym;
                end
            end
            obj.CSIRSPDU = {};
            
            % Fill PDSCH symbols in the grid
            if ~isempty(obj.PDSCHPDU)
                txGrid = populatePDSCH(obj, obj.PDSCHPDU, obj.MacPDU, txGrid, currentTime);
            end
            
            % OFDM modulation
            txWaveform = nrOFDMModulate(carrier, txGrid);
            
            % Trim txWaveform to span only the transmission symbols
            slotNumSubFrame = mod(obj.CurrSlot, obj.WaveformInfoDL.SlotsPerSubframe);
            startSymSubframe = slotNumSubFrame*obj.WaveformInfoDL.SymbolsPerSlot + 1; % Start symbol of current slot in the subframe
            lastSymSubframe = startSymSubframe + obj.WaveformInfoDL.SymbolsPerSlot - 1; % Last symbol of current slot in the subframe
            symbolLengths = obj.WaveformInfoDL.SymbolLengths(startSymSubframe : lastSymSubframe); % Length of symbols of current slot
            startSample = sum(symbolLengths(1:obj.CurrSymbol)) + 1;
            endSample = sum(symbolLengths(1:obj.CurrSymbol+numTxSymbols));
            txWaveform = txWaveform(startSample:endSample, :);
            
            % Signal amplitude. Account for FFT occupancy factor if grid is
            % not fully occupied.
            signalAmp = db2mag(obj.TxPower-30)*sqrt(obj.WaveformInfoDL.Nfft^2/(size(txGrid, 1)*obj.NumTxAnts));
            
            % Construct packet information
            packetInfo.Waveform = signalAmp*txWaveform;
            packetInfo.Position = obj.Node.Position;
            packetInfo.NCellID = obj.CellConfig.NCellID;
            packetInfo.CarrierFreq = obj.CarrierInformation.DLFreq;
            packetInfo.SampleRate = obj.WaveformInfoDL.SampleRate;
            
            % Waveform transmission by sending it to packet
            % distribution entity
            obj.SendPacketFcn(packetInfo);
            
            % Clear the Tx contexts
            obj.PDSCHPDU = {};
            obj.MacPDU = {};
            obj.DataTxTime(obj.CurrSlot*14 + obj.CurrSymbol + 1) = Inf;
        end

        function storeReception(obj, waveformInfo, currentTime)
            %storeReception Receive the incoming waveform and add it to the reception
            % buffer
            
            % Discard the self packet
            if ~isfield(waveformInfo, 'RNTI') && ...
                    (waveformInfo.NCellID == obj.CellConfig.NCellID)
                return;
            end
            
            % Apply channel model
            rxWaveform = applyChannelModel(obj, waveformInfo, currentTime);
            rxWaveformInfo = struct('Waveform', rxWaveform, ...
                'NumSamples', size(rxWaveform, 1), ...
                'SampleRate', waveformInfo.SampleRate, ...
                'StartTime', round(currentTime/1000, 1));
            
            % Store the received waveform in the buffer
            addWaveform(obj.RxBuffer, rxWaveformInfo);
        end
        
        function phyRx(obj, currentTime)
            %phyRx Physical layer reception and sending of decoded information to MAC layer
            %
            % CURRENTTIME - Current time in nanoseconds

            symbolNumFrame = mod(obj.CurrSlot*14 + obj.CurrSymbol - 1, obj.CarrierInformation.SymbolsPerFrame); % Previous symbol number in a 10 ms frame
            puschInfoList = obj.DataRxContext{symbolNumFrame + 1};
            srsInfoList = obj.SRSPDU{symbolNumFrame + 1};
            if isempty(puschInfoList) && isempty(srsInfoList)
                return; % No packet is scheduled to be read at the current symbol
            end

            for i = 1:length(puschInfoList) % For all PUSCH receptions which ended in the last symbol
                puschInfo = puschInfoList{i};
                startSymPUSCH = puschInfo.PUSCHConfig.SymbolAllocation(1);
                numSymPUSCH = puschInfo.PUSCHConfig.SymbolAllocation(2);
                % Calculate the symbol start index w.r.t start of 1 ms sub frame
                slotNumSubFrame = mod(puschInfo.NSlot, obj.WaveformInfoUL.SlotsPerSubframe);
                % Calculate PUSCH duration
                puschSymbolSet = startSymPUSCH : startSymPUSCH+numSymPUSCH-1;
                symbolSetSubFrame = (slotNumSubFrame * 14) + puschSymbolSet + 1;
                duration = 1e6 * (1/obj.WaveformInfoUL.SampleRate) * ...
                    sum(obj.WaveformInfoUL.SymbolLengths(symbolSetSubFrame)); % In microseconds
                
                % Convert channel delay into microseconds
                maxChannelDelay = 1e6 * (1/obj.WaveformInfoUL.SampleRate) * obj.MaxChannelDelay(puschInfo.PUSCHConfig.RNTI);
                
                % Get the received waveform
                duration = duration + maxChannelDelay;
                rxWaveform = getReceivedWaveform(obj.RxBuffer, (currentTime*1e-3) + maxChannelDelay - duration, duration, obj.WaveformInfoUL.SampleRate);

                % Apply receiver antenna gain
                rxWaveform = applyRxGain(obj, rxWaveform);

                % Add thermal noise to the waveform
                rxWaveform = applyThermalNoise(obj, rxWaveform);

                % Process the waveform and send the decoded information to MAC
                phyRxProcessing(obj, rxWaveform, puschInfo, currentTime);
            end
            
            if ~isempty(srsInfoList)
                % The SRS(s) which are currently being read were sent in the
                % last slot. Read the complete last slot and process the
                % SRS(s)
                
                % Calculate the duration of last slot
                if obj.CurrSlot > 0
                    txSlot = obj.CurrSlot-1;
                else
                    txSlot = obj.WaveformInfoUL.SlotsPerSubframe*10-1;
                end
                slotNumSubFrame = mod(txSlot, obj.WaveformInfoUL.SlotsPerSubframe);
                symbolSet = 0:13;
                symbolSetSubFrame = (slotNumSubFrame * 14) + symbolSet + 1;
                duration = 1e6 * (1/obj.WaveformInfoUL.SampleRate) * ...
                    sum(obj.WaveformInfoUL.SymbolLengths(symbolSetSubFrame)); % In microseconds
               
                % Process the SRS and send the measurements to MAC
                for i = 1:length(srsInfoList)
                    % Convert channel delay into microseconds
                    maxChannelDelay = 1e6 * (1/obj.WaveformInfoUL.SampleRate) * obj.MaxChannelDelay(srsInfoList{i}{1});
                    % Get the received waveform
                    rxDuration = duration + maxChannelDelay;
                    rxWaveform = getReceivedWaveform(obj.RxBuffer, (currentTime*1e-3) + maxChannelDelay - rxDuration, rxDuration, obj.WaveformInfoUL.SampleRate);

                    % Apply receiver antenna gain
                    rxWaveform = applyRxGain(obj, rxWaveform);

                    % Add thermal noise to the waveform
                    rxWaveform = applyThermalNoise(obj, rxWaveform);

                    srsRxProcessing(obj, rxWaveform, srsInfoList{i});
                end
                obj.SRSPDU{symbolNumFrame + 1} = {};
            end
           
            % Clear the Rx context
            obj.DataRxContext{symbolNumFrame + 1} = {};
            obj.DataRxTime(symbolNumFrame+1) = Inf;
        end
    end

    methods (Access = private)
        function setWaveformProperties(obj, carrierInformation)
            %setWaveformProperties Set the UL and DL waveform properties
            %   setWaveformProperties(OBJ, CARRIERINFORMATION) sets the UL
            %   and DL waveform properties as per the information in
            %   CARRIERINFORMATION. CARRIERINFORMATION is a structure
            %   including the following fields:
            %       SubcarrierSpacing  - Subcarrier spacing used
            %       NRBsDL             - Downlink bandwidth in terms of
            %                            number of resource blocks
            %       NRBsUL             - Uplink bandwidth in terms of
            %                            number of resource blocks
            
            % Set the UL waveform properties
            obj.WaveformInfoUL = nrOFDMInfo(carrierInformation.NRBsUL, carrierInformation.SubcarrierSpacing);
            
            % Set the DL waveform properties
            obj.WaveformInfoDL = nrOFDMInfo(carrierInformation.NRBsDL, carrierInformation.SubcarrierSpacing);
        end
        
        function updatedSlotGrid = populatePDSCH(obj, pdschPDU, macPDU, txSlotGrid, currentTime)
            %populatePDSCH Populate PDSCH symbols in the Tx grid and return the updated grid
            
            for i=1:length(pdschPDU) % For each PDSCH scheduled for this slot
                pdschInfo = pdschPDU{i};
                % Set transport block in the encoder. In case of empty MAC
                % PDU sent from MAC (indicating retransmission), no need to set transport
                % block as it is already buffered in DL-SCH encoder object
                if ~isempty(macPDU{i})
                    % A non-empty MAC PDU is sent by MAC which indicates new
                    % transmission
                    macPDUBitmap = int2bit(macPDU{i}, 8);
                    macPDUBitmap = reshape(macPDUBitmap', [], 1); % Convert to column vector
                    setTransportBlock(obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}, macPDUBitmap, 0, pdschInfo.HARQID);
                end
                
                if ~isempty(obj.PacketLogger) % Packet capture enabled
                    % Log downlink packets
                    if isempty(macPDU{i})
                        tbID = 0; % Transport block id
                        macPDUBitmap = getTransportBlock(obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}, tbID, pdschInfo.HARQID);
                        macPacket = bit2int(macPDUBitmap, 8);
                        logPackets(obj, pdschInfo, macPacket, 0, currentTime);
                    else
                        logPackets(obj, pdschInfo, macPDU{i}, 0, currentTime);
                    end
                end
                W = pdschInfo.PrecodingMatrix;
                
                % Calculate PDSCH and DM-RS information
                carrierConfig = nrCarrierConfig;
                carrierConfig.NSizeGrid = obj.CarrierInformation.NRBsDL;
                carrierConfig.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
                carrierConfig.NSlot = pdschInfo.NSlot;
                carrierConfig.NCellID = obj.CellConfig.NCellID;
                [pdschIndices, pdschIndicesInfo] = nrPDSCHIndices(carrierConfig, pdschInfo.PDSCHConfig);
                dmrsSymbols = nrPDSCHDMRS(carrierConfig, pdschInfo.PDSCHConfig);
                dmrsIndices = nrPDSCHDMRSIndices(carrierConfig, pdschInfo.PDSCHConfig);
                
                % Encode the DL-SCH transport blocks
                obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}.TargetCodeRate = pdschInfo.TargetCodeRate;
                codedTrBlock = step(obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}, pdschInfo.PDSCHConfig.Modulation, ...
                    pdschInfo.PDSCHConfig.NumLayers, pdschIndicesInfo.G, pdschInfo.RV, pdschInfo.HARQID);

                % PDSCH modulation and precoding
                pdschSymbols = nrPDSCH(carrierConfig, pdschInfo.PDSCHConfig, codedTrBlock);
                [pdschAntSymbols, pdschAntIndices] = nrPDSCHPrecode(carrierConfig, pdschSymbols, pdschIndices, W);
                pdschGrid = zeros(size(txSlotGrid));
                pdschGrid(pdschAntIndices) = pdschAntSymbols;
                
                % PDSCH DM-RS precoding and mapping
                [dmrsAntSymbols, dmrsAntIndices] = nrPDSCHPrecode(carrierConfig, dmrsSymbols, dmrsIndices, W);
                pdschGrid(dmrsAntIndices) = dmrsAntSymbols;
                % PDSCH beamforming
                if ~isempty(pdschInfo.BeamIndex)
                    numPorts = size(pdschGrid, 3);
                    bfGrid = reshape(pdschGrid, [], numPorts)*repmat(obj.BeamWeightTable(:, pdschInfo.BeamIndex)', numPorts, 1);
                    pdschGrid = reshape(bfGrid, size(txSlotGrid));
                end
                txSlotGrid = txSlotGrid + pdschGrid;
            end
            updatedSlotGrid = txSlotGrid;
        end
        
        function rxWaveform = applyChannelModel(obj, pktInfo, currentTime)
            %applyChannelModel Return the waveform after applying channel model
            
            waveform = pktInfo.Waveform;
            % Check if channel model is specified between gNB and a particular UE
            if isfield(pktInfo, 'RNTI') && pktInfo.NCellID == obj.CellConfig.NCellID && ~isempty(obj.ChannelModel{pktInfo.RNTI}) 
                waveform = [waveform; zeros(obj.MaxChannelDelay(pktInfo.RNTI), size(waveform,2))];
                obj.ChannelModel{pktInfo.RNTI}.InitialTime = 1e-9*currentTime; % seconds
                waveform = obj.ChannelModel{pktInfo.RNTI}(waveform);
            else
                % Channel matrix to map the waveform from NumTxAnts to
                % NumRxAnts in the absence of CDL channel model
                numTxAnts = size(waveform, 2);
                H = fft(eye(max([numTxAnts obj.NumRxAnts])));
                H = H(1:numTxAnts,1:obj.NumRxAnts);
                H = H / norm(H);
                waveform = waveform * H;
            end
            
            % Apply path loss on the waveform
            distance = getNodeDistance(obj.Node, pktInfo.Position); % Calculate the distance between source and destination nodes
            lambda = physconst('LightSpeed')/pktInfo.CarrierFreq; % Wavelength
            % Calculate the path loss
            pathLoss = fspl(distance, lambda);
            rxWaveform = db2mag(-pathLoss)*waveform;
        end
        
        function phyRxProcessing(obj, rxWaveform, puschInfo, currentTime)
            %phyRxProcessing Read the PUSCH as per the passed PUSCH information and send the decoded information to MAC
            
            % Get the Tx slot
            if obj.CurrSymbol == 0 % Current symbol is first in the slot hence transmission was done in the last slot
                if obj.CurrSlot > 0
                    txSlot = obj.CurrSlot-1;
                    txSlotAFN = obj.AFN; % Tx slot was in the current frame
                else
                    txSlot = obj.WaveformInfoUL.SlotsPerSubframe*10-1;
                    txSlotAFN = obj.AFN - 1; % Tx slot was in the previous frame
                end
                lastSym = obj.WaveformInfoUL.SymbolsPerSlot-1; % Last symbol number of the waveform
            else % Transmission was done in the current slot
                txSlot = obj.CurrSlot;
                txSlotAFN = obj.AFN; % Tx slot was in the current frame
                lastSym = obj.CurrSymbol - 1; % Last symbol number of the waveform
            end
            startSym = lastSym - puschInfo.PUSCHConfig.SymbolAllocation(2) + 1;
             
            % Carrier information
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsUL;
            carrier.NSlot = txSlot;
            carrier.NFrame = txSlotAFN;
            carrier.NCellID = obj.CellConfig.NCellID;
            
            % Populate the received waveform at appropriate indices in the slot-length waveform
            slotNumSubFrame = mod(txSlot, obj.WaveformInfoUL.SlotsPerSubframe);
            startSymSubframe = slotNumSubFrame*obj.WaveformInfoUL.SymbolsPerSlot + 1; % Start symbol of tx slot in the subframe
            lastSymSubframe = startSymSubframe + obj.WaveformInfoUL.SymbolsPerSlot -1; % Last symbol of tx slot in the subframe
            symbolLengths = obj.WaveformInfoUL.SymbolLengths(startSymSubframe : lastSymSubframe); % Length of symbols of tx slot
            slotWaveform = zeros(sum(symbolLengths) + obj.MaxChannelDelay(puschInfo.PUSCHConfig.RNTI), obj.NumRxAnts);
            startSample = sum(symbolLengths(1:startSym)) + 1;
            slotWaveform(startSample : startSample+length(rxWaveform)-1, :) = rxWaveform;
            
            % Get PUSCH and DM-RS information
            [puschIndices, ~] = nrPUSCHIndices(carrier, puschInfo.PUSCHConfig);
            puschInfo.PUSCHConfig.TransmissionScheme = 'nonCodebook';
            dmrsSymbols = nrPUSCHDMRS(carrier, puschInfo.PUSCHConfig);
            dmrsIndices = nrPUSCHDMRSIndices(carrier, puschInfo.PUSCHConfig);
            
            % Set TBS
            obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}.TransportBlockLength = puschInfo.TBS*8;
            
            % Practical synchronization. Correlate the received waveform
            % with the PUSCH DM-RS to give timing offset estimate 't' and
            % correlation magnitude 'mag'
            [t, mag] = nrTimingEstimate(carrier, slotWaveform, dmrsIndices, dmrsSymbols);
            obj.TimingOffset(puschInfo.PUSCHConfig.RNTI) = hSkipWeakTimingOffset(obj.TimingOffset(puschInfo.PUSCHConfig.RNTI), t, mag);
            if(obj.TimingOffset(puschInfo.PUSCHConfig.RNTI) > obj.MaxChannelDelay(puschInfo.PUSCHConfig.RNTI))
                % Ignore the timing offset estimate resulting from weak correlation
                obj.TimingOffset(puschInfo.PUSCHConfig.RNTI) = 0;
            end
            
            slotWaveform = slotWaveform(1+obj.TimingOffset(puschInfo.PUSCHConfig.RNTI):end, :);
            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGrid = nrOFDMDemodulate(carrier, slotWaveform);
            [K, L, R] = size(rxGrid);
            if (L < obj.WaveformInfoUL.SymbolsPerSlot)
                rxGrid = cat(2, rxGrid, zeros(K, obj.WaveformInfoUL.SymbolsPerSlot-L, R));
            end
            
            % Practical channel estimation between the received grid
            % and each transmission layer, using the PUSCH DM-RS for
            % each layer
            [estChannelGrid, noiseEst] = nrChannelEstimate(rxGrid, dmrsIndices, dmrsSymbols, 'CDMLengths', puschInfo.PUSCHConfig.DMRS.CDMLengths, 'AveragingWindow',[0 7]);
            
            % Get PUSCH resource elements from the received grid
            [puschRx, puschHest] = nrExtractResources(puschIndices, rxGrid, estChannelGrid);
            
            % Equalization
            [puschEq, csi] = nrEqualizeMMSE(puschRx, puschHest, noiseEst);
            
            % Decode PUSCH physical channel
            [ulschLLRs, rxSymbols] = nrPUSCHDecode(carrier, puschInfo.PUSCHConfig, puschEq, noiseEst);
            
            csi = nrLayerDemap(csi);
            Qm = length(ulschLLRs) / length(rxSymbols);
            csi = reshape(repmat(csi{1}.',Qm,1),[],1);
            ulschLLRs = ulschLLRs .* csi;
            
            % Decode the UL-SCH transport channel
            obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}.TargetCodeRate = puschInfo.TargetCodeRate;
            [decbits, crcFlag] = step(obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}, ulschLLRs, ...
                puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, puschInfo.RV, puschInfo.HARQID);
            
            if puschInfo.RV == obj.RVSequence(end)
                % The last redundancy version failed. Reset the soft buffer
                resetSoftBuffer(obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}, puschInfo.HARQID);
            end

            % Convert bit stream to byte stream
            macPDU = bit2int(decbits, 8);
            
            % Rx callback to MAC
            macPDUInfo = hNRRxIndicationInfo;
            macPDUInfo.RNTI = puschInfo.PUSCHConfig.RNTI;
            macPDUInfo.TBS = puschInfo.TBS;
            macPDUInfo.HARQID = puschInfo.HARQID;
            obj.RxIndicationFcn(macPDU, crcFlag, macPDUInfo); % Send PDU to MAC
            
            % Increment the number of erroneous packets received for UE
            obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 1) = obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 1) + crcFlag;
            % Increment the number of received packets for UE
            obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 2) = obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 2) + 1;
            
            if ~isempty(obj.PacketLogger) % Packet capture enabled
                logPackets(obj, puschInfo, macPDU, 1, currentTime); % Log UL packets
            end
        end
        
        function srsRxProcessing(obj, rxWaveform, srsInfo)
            %srsRxProcessing Process the contained SRS(s) in waveform and send the measurements to MAC 
            
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsUL;
            
            % Get the Tx slot
            if obj.CurrSlot > 0
                txSlot = obj.CurrSlot-1;
                txSlotAFN = obj.AFN; % Tx slot was in the current frame
            else
                txSlot = obj.WaveformInfoUL.SlotsPerSubframe*10-1;
                % Tx slot was in the previous frame
                txSlotAFN = obj.AFN - 1;
            end
            carrier.NSlot = txSlot;
            carrier.NFrame = txSlotAFN;
            
            rnti = srsInfo{1}; % UE from which SRS is received
            srsConfig = srsInfo{2};% SRS configuration used by the UE
            srsInd = nrSRSIndices(carrier, srsConfig);
            srsSym = nrSRS(carrier, srsConfig);
            % Calculate timing offset
            [t, mag] = nrTimingEstimate(carrier, rxWaveform, srsInd, srsSym);
            obj.TimingOffset(rnti) = hSkipWeakTimingOffset(obj.TimingOffset(rnti), t, mag);
            if obj.TimingOffset(rnti) > obj.MaxChannelDelay(rnti)
                % Ignore the timing offset estimate resulting from weak correlation
                obj.TimingOffset(rnti) = 0;
            end
            rxWaveform = rxWaveform(1+obj.TimingOffset(rnti):end, :);
            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGrid = nrOFDMDemodulate(carrier, rxWaveform);
            [K, L, R] = size(rxGrid);
            if (L < obj.WaveformInfoUL.SymbolsPerSlot)
                rxGrid = cat(2, rxGrid, zeros(K, obj.WaveformInfoUL.SymbolsPerSlot-L, R));
            end
            
            % If SRS is present in waveform, measure UL channel quality
            if ~isempty(srsConfig)
                srsRefInd = nrSRSIndices(carrier, srsConfig);
                if ~isempty(srsRefInd)
                    srsSym = nrSRS(carrier, srsConfig);
                    cdmLen = hSRSCDMLengths(srsConfig);
                    % Estimated channel and noise variance
                    [Hest, nVar] = nrChannelEstimate(rxGrid, srsRefInd, srsSym, 'AveragingWindow',[0 7], 'CDMLengths', cdmLen);

                    rank = obj.RankIndicator(rnti);
                    srsSymbols = srsConfig.SymbolStart + (1:srsConfig.NumSRSSymbols);
                    subbandSize = obj.SRSSubbandSize;
                    [pmi, sinrSubband, ~] = hPMISelect(rank, Hest(:,srsSymbols,:,:), nVar, subbandSize);
                    nanPMIIdx = isnan(pmi);
                    if any(nanPMIIdx) % Take average PMI and SINR of other subbands having SRS measurements
                        pmi(nanPMIIdx == 1) = floor(mean(pmi(nanPMIIdx == 0)));
                        sinrSubband(nanPMIIdx == 1, :) = mean(sinrSubband(nanPMIIdx == 0, :), 1);
                    end
                    sinrSubbandPMI = zeros(1, size(sinrSubband, 1));
                    for i=1:length(pmi)
                        sinrSubbandPMI(i) = sinrSubband(i, pmi(i)+1);
                    end
                   
                    % Convert CQI of sub-bands to per-RB CQI
                    cqiRBs = zeros(obj.CarrierInformation.NRBsUL, 1);
                    numSubbands = length(sinrSubbandPMI);
                    sinrTable = obj.SINRTable;
                    for i = 1:numSubbands-1
                        cqi = find(sinrTable(sinrTable <= 10*log10(sinrSubbandPMI(i))), 1, 'last');
                        if ~isempty(cqi)
                            cqiRBs((i-1)*subbandSize+1 : i*subbandSize) = cqi-1;
                        end
                    end
                    cqiRBs((numSubbands-1)*subbandSize+1:end) = cqiRBs((numSubbands-1)*subbandSize);
                    cqiRBs(cqiRBs<=1) = 1; % Ensuring minimum CQI as 1
                    % Send the measurement report to MAC
                    obj.SRSIndicationFcn(rnti, rank, pmi, cqiRBs);
                end
            end
        end
        
        function waveformOut = applyRxGain(obj, waveformIn)
            %applyRxGain Apply receiver antenna gain
            
            scale = 10.^(obj.RxGain/20);
            waveformOut = waveformIn.* scale;
        end
        
        function waveformOut = applyThermalNoise(obj, waveformIn)
            %applyThermalNoise Apply thermal noise
            
            noiseFigure = 10^(obj.NoiseFigure/10);
            % Thermal noise (in Watts)
            Nt = physconst('Boltzmann')*(obj.AntNoiseTemperature + 290*(noiseFigure-1))*obj.WaveformInfoUL.SampleRate;
            noise = sqrt(Nt/2)*complex(randn(size(waveformIn)),randn(size(waveformIn)));
            waveformOut = waveformIn + noise;

        end
        
        function logPackets(obj, info, macPDU, linkDir, currentTime)
            %logPackets Capture the MAC packets to a PCAP file
            %
            % logPackets(OBJ, INFO, MACPDU, LINKDIR)
            %
            % INFO - Contains the PUSCH/PDSCH information
            %
            % MACPDU - MAC PDU
            %
            % LINKDIR - 1 represents UL and 0 represents DL direction
            %
            % CURRENTTIME - Current time in nanoseconds

            obj.PacketMetaData.HARQID = info.HARQID;
            obj.PacketMetaData.SlotNumber = info.NSlot;
            
            if linkDir % Uplink
                % Get frame number of previous slot i.e the Tx slot. Reception ended at the
                % end of previous slot
                if obj.CurrSlot > 0
                    prevSlotAFN = obj.AFN; % Previous slot was in the current frame
                else
                    % Previous slot was in the previous frame
                    prevSlotAFN = obj.AFN - 1;
                end
                obj.PacketMetaData.SystemFrameNumber = mod(prevSlotAFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Uplink;
                obj.PacketMetaData.RNTI = info.PUSCHConfig.RNTI;
            else % Downlink
                obj.PacketMetaData.SystemFrameNumber = mod(obj.AFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Downlink;
                obj.PacketMetaData.RNTI = info.PDSCHConfig.RNTI;
            end
            write(obj.PacketLogger, macPDU, round(currentTime*1e-3), 'PacketInfo', obj.PacketMetaData);
        end

        function nextInvokeTime = getNextInvokeTime(obj, currentTime)
            %getNextInvokeTime Return the next invoke time in nanoseconds

            % Find the next invoke time for PHY Tx
            pdschTxNextInvokeTime = min(obj.DataTxTime);

            %  Find the next invoke time for SRS reception
            if obj.NextSRSRxTime > currentTime
                srsRxNextInvokeTime = obj.NextSRSRxTime;
            else
                srsRxNextInvokeTime = Inf;
            end

            % Find the next PHY Rx invoke time
            puschRxNextInvokeTime = min(obj.DataRxTime);

            nextInvokeTime = min([pdschTxNextInvokeTime puschRxNextInvokeTime srsRxNextInvokeTime]);
        end
    end

    methods (Hidden = true)
        function dlTTIRequest(obj, pduType, dlControlPDU)
            dlControlRequest(obj, pduType, dlControlPDU);
        end
    end
end