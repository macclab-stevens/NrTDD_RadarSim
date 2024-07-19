classdef hNRUEPhy < hNRPhyInterface
    %hNRUEPhy 5G NR Phy Tx and Rx processing chains at UE
    %   The class implements the Phy Tx and Rx processing chains of 5G NR
    %   at UE. It also implements the interfaces for information exchange
    %   between Phy and higher layers. It only supports transmission of
    %   physical uplink shared channel (PUSCH) along with its demodulation
    %   reference signals (DM-RS). It only supports reception of physical
    %   downlink shared channel (PDSCH) along with its DM-RS. A single
    %   bandwidth part is assumed to cover the entire carrier bandwidth.
    %   Note that setCarrierInformation and setCellConfig need to be called
    %   on the created class object before using it.
    %
    %   hNRUEPhy methods:
    %       hNRUEPhy                - Construct a UE Phy object
    %       run                     - Run the UE Phy layer operations
    %       setCarrierInformation   - Set the carrier configuration
    %       enablePacketLogging     - Enable packet logging
    %       registerMACInterfaceFcn - Register MAC interface functions at 
    %                                 Phy, for sending information to MAC
    %       registerInBandTxFcn     - Register callback for transmission on
    %                                 PUSCH
    %       txDataRequest           - Tx request from MAC to Phy for 
    %                                 starting PUSCH transmission
    %       dlControlRequest        - Downlink control (non-data) reception request
    %                                 from MAC to Phy
    %       ulControlRequest        - Uplink control (non-data) transmission request 
    %                                 from MAC to Phy
    %       rxDataRequest           - Rx request from MAC to Phy for 
    %                                 starting PDSCH reception
    %       phyTx                   - Physical layer processing and
    %                                 transmission
    %       storeReception          - Receive the waveform and add it to the
    %                                 reception buffer
    %       phyRx                   - Physical layer reception and sending
    %                                 of decoded information to MAC layer
    %
    %   Example: 
    %   % Generate a hNRUEPhy object. Configure the carrier and cell 
    %   % properties using setCarrierInformation and setCellConfig methods,
    %   % respectively
    %
    %   phyParam = struct();
    %   phyParam.SCS = 15;
    %   phyParam.NumRBs = 52;
    %   phyParam.UETxPower = 23;
    %   phyParam.DLCarrierFreq = 2.1e9;
    %   phyParam.UERxBufferSize = 1;
    % 
    %   % Configure the downlink channel model
    %   channel = nrCDLChannel;
    %   channel.DelayProfile = 'CDL-C';
    %   channel.DelaySpread = 300e-9;
    %   channel.CarrierFrequency = phyParam.DLCarrierFreq;
    %   channel.TransmitAntennaArray.Size = [1 1 1 1 1];
    %   channel.ReceiveAntennaArray.Size = [1 1 1 1 1];
    %   waveformInfo = nrOFDMInfo(phyParam.NumRBs, phyParam.SCS);
    %   channel.SampleRate = waveformInfo.SampleRate;
    %   phyParam.ChannelModel = channel;
    %
    %   rnti = 1;
    %   phy = hNRUEPhy(phyParam, rnti);
    %
    %   carrierParam = struct();
    %   carrierParam.SubcarrierSpacing = phyParam.SCS;
    %   carrierParam.NRBsUL = phyParam.NumRBs;
    %   carrierParam.NRBsDL = phyParam.NumRBs;
    %   carrierParam.DLFreq = phyParam.DLCarrierFreq;
    %   setCarrierInformation(phy, carrierParam);
    %
    %   cellParam.NCellID = 1;
    %   cellParam.DuplexMode = 0;
    %   setCellConfig(phy, cellParam)
    %
    %   See also hNRPhyInterface
    
    %   Copyright 2020-2023 The MathWorks, Inc.
    properties
        %DLBlkErr Downlink block error information
        % It is an array of two elements containing the number of
        % erroneously received packets and total received packets,
        % respectively
        DLBlkErr
    end

    properties (Access = private)
        %RNTI RNTI of the UE
        RNTI (1, 1){mustBeInRange(RNTI, 1, 65519)} = 1;
        
        %ULSCHEncoder Uplink shared channel (UL-SCH) encoder system object
        % It is an object of type nrULSCH
        ULSCHEncoder
        
        %DLSCHDecoder Downlink shared channel (DL-SCH) decoder system object
        % It is an object of type nrDLSCHDecoder
        DLSCHDecoder
        
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
        NumTxAnts (1, 1) {mustBeMember(NumTxAnts, [1,2,4,8,16])} = 1 

        %NumRxAnts Number of receive antennas
        NumRxAnts (1, 1) {mustBeMember(NumRxAnts, [1,2,4,8,16])} = 1 

        %TxPower Tx power in dBm
        TxPower(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 23;
        
        %RxGain Rx antenna gain in dBi
        RxGain(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 0;
        
        %PUSCHPDU Physical uplink shared channel (PUSCH) information sent by MAC for the current slot
        % PUSCH PDU is an object of type hNRPUSCHInfo. It has the
        % information required by Phy to transmit the MAC PDU stored in
        % object property MacPDU
        PUSCHPDU = {}
        
        %MacPDU PDU sent by MAC which is scheduled to be transmitted in the currrent slot
        % The information required to transmit this PDU is stored in object
        % property PUSCHPDU
        MacPDU = {}
        
        %SRSPDU SRS information PDU sent by MAC for the current slot
        % It is an object of type nrSRSConfig containing the
        % configuration of SRS to be sent in current slot. If empty,
        % then SRS is not scheduled for the current slot
        SRSPDU = {}
        
        %CSIRSContext Rx context for the channel state information reference signals (CSI-RS)
        % This information is populated by MAC and is used by Phy to
        % receive UE's scheduled CSI-RS. It is a cell array of size 'N'
        % Cell array of size 'N' where N is the number of symbols in a 10 ms
        % frame. The cell elements are populated with objects of type
        % nrCSIRSConfig. An element at index 'i' contains the CSI-RS
        % configuration which is sent in the symbol index 'i-14' (i.e
        % '(i-1)/14)' slot). Cell element at 'i' is empty if no CSI-RS
        % reception was scheduled in the symbol 'i-14'
        CSIRSContext
        
        %CSIRSIndicationFcn Function handle to send the measured DL channel quality to MAC
        CSIRSIndicationFcn
        
        %CSIReportConfig CSI report configuration
        % The detailed explanation of this structure and its fields is
        % present as ReportConfig in <a href="matlab:help('hCQISelect')">hCQISelect</a> function
        CSIReportConfig

        %SINRvsCQI SINR to CQI mapping
        % SINRTable is a vector of 15 SINR values in dB, each corresponding to a
        % CQI value that have been computed according to the BLER condition as
        % mentioned in TS 38.214 Section 5.2.2.1
        SINRTable
        
        %NoiseFigure Noise figure at the receiver
        NoiseFigure = 6;

        %AntNoiseTemperature Antenna temperature at node in Kelvin
        % It is used for thermal noise calculation
        AntNoiseTemperature = 290
               
        %ChannelModel Information about the propagation channel model
        % This property is an object of type nrCDLChannel if the
        % ChannelModelType is specified as 'CDL', otherwise empty
        ChannelModel
        
        %MaxChannelDelay Maximum delay introduced due to multipath components and implementation delays
        MaxChannelDelay = 0;
        
        %TimingOffset Receiver timing offset 
        TimingOffset = 0;
        
        %RxBuffer Reception buffer object to store received waveforms
        RxBuffer

        %PacketLogger Contains handle of the PCAP object
        PacketLogger
        
        %PacketMetaData Contains the information required for logging MAC
        %packets into PCAP
        PacketMetaData

        %RVSequence Redundancy version sequence
        RVSequence = [0 3 2 1]

        %NextCSIRSRxTime Next CSI-RS reception time in nanoseconds
        NextCSIRSRxTime = -1
    end
    
    methods
        function obj = hNRUEPhy(param, rnti)
            %hNRUEPhy Construct a UE Phy object
            %   OBJ = hNRUEPHY(PARAM, RNTI) constructs a UE Phy object. It
            %   also creates the context of UL-SCH encoder system object
            %   and DL-SCH decoder system object.
            %
            %   PARAM is structure with the fields:
            %     SCS              - Subcarrier spacing
            %     UETxPower        - UE Tx Power in dBm
            %     UERxGain         - UE Rx antenna gain in dBi
            %     DownlinkSINR90pc - SINR to CQI look up table. An array of
            %                        16 SINR values correspond to 16 CQI
            %                        values (0 to 15). The look up table
            %                        contains the CQI resulting in a
            %                        maximum of 0.1 BLER for the
            %                        corresponding SINR.
            %     NumRBs           - Number of resource blocks
            %     DLCarrierFreq    - Downlink carrier frequency in Hz
            %     UERxBufferSize   - Maximum number of waveforms to be
            %                        stored
            %     ChannelModel     - Propagation channel model between
            %                        the gNB and the UE in the downlink
            %                        direction. In case of CDL channel
            %                        model, it is an object of type
            %                        nrCDLChannel. Default value is
            %                        empty.
            %     UETxAnts         - Number of Tx antennas on UEs
            %     UERxAnts         - Number of Rx antennas on UEs
            %     CSIReportConfig  - CSI Report configuration. It is a structure with the following fields:
            %                          CQIMode     - CQI reporting mode. Value as 'Subband' or 'Wideband'
            %                          SubbandSize - Subband size for CQI or PMI reporting as per TS 38.214 Table 5.2.1.4-2
            %                        Additional fields for MIMO systems:                       
            %                          PanelDimensions - Antenna panel configuration as a two-element vector in the form of [N1 N2].
            %                                            N1 represents the number of antenna elements in horizontal direction and
            %                                            N2 represents the number of antenna elements in vertical direction. Valid
            %                                            combinations of [N1 N2] are defined in 3GPP TS 38.214 Table 5.2.2.2.1-2
            %                          PMIMode         - PMI reporting mode. Value as 'Subband' or 'Wideband'
            %                          CodebookMode    - Codebook mode. Value as 1 or 2
            %
            %       EnableHARQ       - Flag to enable/disable retransmissions
            %       RVSequence       - Redundancy version sequence to be followed
            %
            %   RNTI - RNTI of the UE
            
            % Validate the subcarrier spacing
            if ~ismember(param.SCS, [15 30 60 120])
                error('nr5g:hNRUEPhy:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120).', param.SCS);
            end
            
            obj.RNTI = rnti;
            
            % Create UL-SCH encoder system object
            ulschEncoder = nrULSCH;
            ulschEncoder.MultipleHARQProcesses = true;
            obj.ULSCHEncoder = ulschEncoder;
            
            % Create DL-SCH decoder system object
            dlschDecoder = nrDLSCHDecoder;
            dlschDecoder.MultipleHARQProcesses = true;
            dlschDecoder.LDPCDecodingAlgorithm = 'Normalized min-sum';
            dlschDecoder.MaximumLDPCIterationCount = 6;
            obj.DLSCHDecoder = dlschDecoder;
            
            % Set the number of erroneous packets and total number of
            % packets received by the UE to zero
            obj.DLBlkErr = zeros(1, 2);
            
            obj.CSIRSContext = cell(10*(param.SCS/15)*14, 1); % Create the context for all the symbols in the frame
            % Set SINR vs CQI lookup table
            if isfield(param, 'DownlinkSINR90pc')
                obj.SINRTable = param.DownlinkSINR90pc;
            elseif isfield(param, 'SINR90pc') % For backward compatibility
                obj.SINRTable = param.SINR90pc;
            else
                obj.SINRTable = [-5.46 -0.46 4.54 9.05 11.54 14.04 15.54 18.04 ...
                    20.04 22.43 24.93 25.43 27.43 30.43 33.43];
            end
            
            if isfield(param, 'UETxAnts')
                obj.NumTxAnts = param.UETxAnts;
            end
          
            if isfield(param, 'RxAntPanel')
                obj.RxAntPanel = param.RxAntPanel;
                obj.NumRxAnts = prod(param.RxAntPanel.Size);
            elseif isfield(param, 'UERxAnts')
                obj.NumRxAnts = param.UERxAnts;
            end

            % Set CSI report config
            if isfield(param, 'CSIReportConfig')
                obj.CSIReportConfig = param.CSIReportConfig;
                obj.CSIReportConfig.NStartBWP = 0;
                obj.CSIReportConfig.NSizeBWP = param.NumRBs;
            else
                csiReportConfig.NStartBWP = 0;
                csiReportConfig.NSizeBWP = param.NumRBs;
                csiReportConfig.CQIMode = 'Subband';
                csiReportConfig.PMIMode = 'Subband';
                csiReportConfig.SubbandSize = 4;
                csiReportConfig.PRGSize = [];
                csiReportConfig.CodebookMode = 1;
                obj.CSIReportConfig = csiReportConfig;
            end
            
            % Set Tx power in dBm
            if isfield(param, 'UETxPower')
                obj.TxPower = param.UETxPower;
            end
            
            % Set Rx antenna gain in dBi
            if isfield(param, 'UERxGain')
                obj.RxGain = param.UERxGain;
            end
            
            if isfield(param, 'ChannelModel')
                obj.ChannelModel = param.ChannelModel;
                chInfo = info(obj.ChannelModel);
                obj.MaxChannelDelay = chInfo.MaximumChannelDelay;
            end
            
            % Set receiver noise figure
            if isfield(param, 'NoiseFigure')
                obj.NoiseFigure = param.NoiseFigure;
            end
            
            % Create reception buffer object
            if isfield(param, 'UERxBufferSize')
                obj.RxBuffer = hNRPhyRxBuffer('BufferSize', param.UERxBufferSize, 'NRxAnts', obj.NumRxAnts);
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
                validateattributes(param.EnableHARQ, {'logical', 'numeric'}, {'nonempty', 'integer', 'scalar'}, 'param.EnableHARQ', 'EnableHARQ');
                if isnumeric(param.EnableHARQ)
                    % To support 0/1
                    validateattributes(param.EnableHARQ, {'numeric'}, {'>=', 0, '<=', 1}, 'param.EnableHARQ', 'EnableHARQ');
                end
                if ~param.EnableHARQ
                    % No retransmissions
                    obj.RVSequence = 0;
                end
            end
        end
        
        function nextInvokeTime = run(obj, currentTime, packets)
            %run Run the UE Phy layer operations and return the next invoke
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


            % Phy processing and transmission of PUSCH (along with its
            % DM-RS). It assumes that MAC has already loaded the Phy Tx
            % context for anything scheduled to be transmitted at the
            % current symbol
            phyTx(obj, currentTime);

            % Store the received packet
            for pktIdx = 1:numel(packets)
                if ~isfield(packets{pktIdx}, 'PacketType')
                    storeReception(obj, packets{pktIdx}, currentTime);
                end
            end

            % Phy reception of PDSCH (along with its DM-RS) and CSI-RS, and
            % then sending the decoded information to MAC. PDSCH Rx is done
            % in the symbol after the last symbol in PDSCH duration (till
            % then the packets are queued in Rx buffer). Phy calculates the
            % last symbol of PDSCH duration based on 'rxDataRequest' call
            % from MAC (which comes at the first symbol of PDSCH Rx time)
            % and the PDSCH duration. CSI-RS reception is done at the start
            % of slot which is after the scheduled CSI-RS reception slot
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
        
        function timestamp = getCurrentTime(obj)
            %getCurrentTime Return the current timestamp of node in microseconds
            
            % Calculate number of samples from the start of the current
            % frame to the current symbol
            numSubFrames = floor(obj.CurrSlot / obj.WaveformInfoDL.SlotsPerSubframe);
            numSlotSubFrame = mod(obj.CurrSlot, obj.WaveformInfoDL.SlotsPerSubframe);
            symbolNumSubFrame = numSlotSubFrame*obj.WaveformInfoDL.SymbolsPerSlot + obj.CurrSymbol;
            numSamples = (numSubFrames * sum(obj.WaveformInfoDL.SymbolLengths))...
                + sum(obj.WaveformInfoDL.SymbolLengths(1:symbolNumSubFrame));
            
            % Timestamp in microseconds
            timestamp = (obj.AFN * 0.01) + (numSamples *  1 / obj.WaveformInfoDL.SampleRate);
            timestamp = (1e6 * timestamp);
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
            obj.PacketMetaData.RNTI = obj.RNTI;
        end
        
        function registerMACInterfaceFcn(obj, sendMACPDUFcn, sendDLChannelQualityFcn)
            %registerMACInterfaceFcn Register MAC interface functions at Phy, for sending information to MAC
            %   registerMACInterfaceFcn(OBJ, SENDMACPDUFCN,
            %   SENDDLCHANNELQUALITYFCN) registers the callback function to
            %   send decoded MAC PDUs and measured DL channel quality to MAC.
            %
            %   SENDMACPDUFCN Function handle provided by MAC to Phy for
            %   sending PDUs to MAC.
            %
            %   SENDDLCHANNELQUALITYFCN Function handle provided by MAC to Phy for
            %   sending the measured DL channel quality (measured on CSI-RS).
            
            obj.RxIndicationFcn = sendMACPDUFcn;
            obj.CSIRSIndicationFcn = sendDLChannelQualityFcn;
        end
        
        function txDataRequest(obj, PUSCHInfo, macPDU, ~)
            %txDataRequest Tx request from MAC to Phy for starting PUSCH transmission
            %  txDataRequest(OBJ, PUSCHINFO, MACPDU) sets the Tx context to
            %  indicate PUSCH transmission in the current symbol
            %
            %  PUSCHInfo is an object of type hNRPUSCHInfo sent by MAC. It
            %  contains the information required by the Phy for the
            %  transmission.
            %
            %  MACPDU is the uplink MAC PDU sent by MAC for transmission.
            
            obj.PUSCHPDU = PUSCHInfo;
            obj.MacPDU = macPDU;
        end
       
        function dlControlRequest(obj, pduType, dlControlPDU, timingInfo)
            %dlControlRequest Downlink control (non-data) reception request from MAC to Phy
            %   dlControlRequest(OBJ, PDUTYPES, DLCONTROLPDUS, TIMINGINFO)
            %   is a request from MAC for downlink receptions. MAC sends it
            %   at the start of a DL slot for all the scheduled non-data DL
            %   receptions in the slot (Data i.e. PDSCH reception
            %   information is sent by MAC using rxDataRequest interface of
            %   this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only
            %   packet type 0 (CSI-RS) is supported.
            %
            %   DLCONTROLPDU is an array of DL control information PDUs,
            %   corresponding to packet types in PDUTYPE. Currently
            %   supported information CSI-RS PDU is an object of type
            %   nrCSIRSConfig.
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     CurrSlot   - Current slot number in a 10 millisecond frame
            %     CurrSymbol - Current symblo number in the current slot
            %     Timestamp - Reception start timestamp in nanoseconds.

            % Update the Rx context for DL receptions
            for i = 1:length(pduType)
                switch pduType(i)
                    case obj.CSIRSPDUType
                        % Channel quality would be read at the end of the current slot
                        currSlot = mod(timingInfo.CurrSlot, obj.CarrierInformation.SlotsPerSubframe*10);
                        rxSymbolFrame = (currSlot+1) * 14;
                        obj.CSIRSContext{rxSymbolFrame}{end+1} = dlControlPDU{i};
                        obj.NextCSIRSRxTime = timingInfo.Timestamp + obj.CarrierInformation.SlotDuration; % In nanoseconds
                end
            end
        end
        
        function ulControlRequest(obj, pduType, ulControlPDU, ~)
            %ulControlRequest Uplink transmission request (non-data) from MAC to Phy
            %   ulControlRequest(OBJ, PDUTYPES, ULCONTROLPDU) is a request from
            %   MAC for uplink transmissions. MAC sends it at the start of a
            %   UL slot for all the scheduled non-data UL transmissions in the
            %   slot (Data i.e. PUSCH transmissions information is sent by MAC
            %   using txDataRequest interface of this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only
            %   packet type 1 (SRS) is supported.
            %
            %   ULCONTROLPDU is an array of UL control information PDUs,
            %   corresponding to packet types in PDUTYPE. Currently
            %   supported information SRS PDU is an object of type
            %   nrSRSConfig.
            
            % Update the Tx context
            for i = 1:length(pduType)
                switch(pduType(i))
                    case obj.SRSPDUType
                        obj.SRSPDU = ulControlPDU{i};
                end
            end
        end
        
        function rxDataRequest(obj, pdschInfo, timingInfo)
            %rxDataRequest Rx request from MAC to Phy for starting PDSCH reception
            %   rxDataRequest(OBJ, PDSCHINFO, TIMINGINFO) is a request to
            %   start PDSCH reception. It starts a timer for PDSCH end time
            %   (which on triggering receives the complete PDSCH). The Phy
            %   expects the MAC to send this request at the start of
            %   reception time.
            %
            %   PDSCHInfo is an object of type hNRPDSCHInfo. It contains the
            %   information required by the Phy for the reception.
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     CurrSlot   - Current slot number in a 10 millisecond frame
            %     CurrSymbol - Current symblo number in the current slot
            %     Timestamp - Reception start timestamp in nanoseconds.

            pdschStartSym = pdschInfo.PDSCHConfig.SymbolAllocation(1);
            symbolNumFrame = pdschInfo.NSlot*14 + pdschStartSym; % PDSCH Rx start symbol number w.r.t start of 10 ms frame
            
            % PDSCH to be read at the end of last symbol in PDSCH reception
            numPDSCHSym =  pdschInfo.PDSCHConfig.SymbolAllocation(2);
            pdschRxSymbolFrame = mod(symbolNumFrame + numPDSCHSym, obj.CarrierInformation.SymbolsPerFrame+1);
            
            symDur = obj.CarrierInformation.SymbolDurations; % In nanoseconds
            startSymbolIdx = pdschStartSym + 1;
            endSymbolIdx = pdschStartSym + numPDSCHSym;

            % Add the PDSCH Rx information at the index corresponding to
            % the symbol where PDSCH Rx ends
            obj.DataRxContext{pdschRxSymbolFrame} = pdschInfo;
            % Store data reception time (in nanoseconds) information
            obj.DataRxTime(pdschRxSymbolFrame) = timingInfo.Timestamp + ...
                sum(symDur(startSymbolIdx:endSymbolIdx));
        end
        
        function phyTx(obj, currentTime)
            %phyTx Physical layer processing and transmission
            %
            % CURRENTTIME - Current time in nanoseconds

            if isempty(obj.PUSCHPDU) && isempty(obj.SRSPDU)
                return; % No transmission (PUSCH or SRS) is scheduled to start at the current symbol
            end
            
            % Set carrier configuration
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsUL;
            carrier.NSlot = obj.CurrSlot;
            
            % Initialize Tx grid
            txSlotGrid = zeros(obj.CarrierInformation.NRBsUL*12, obj.WaveformInfoUL.SymbolsPerSlot, obj.NumTxAnts);
            
            numTxSymbols = 0; % Initialize Tx waveform length in symbols
            % Fill SRS in the grid
            if ~isempty(obj.SRSPDU)
                numTxSymbols = obj.SRSPDU.SymbolStart + obj.SRSPDU.NumSRSSymbols;
                srsInd = nrSRSIndices(carrier, obj.SRSPDU);
                srsSym = nrSRS(carrier, obj.SRSPDU);
                % Placing the SRS in the Tx grid
                txSlotGrid(srsInd) = srsSym;
                obj.SRSPDU = {};
            end
            
            % Fill PUSCH symbols in the grid
            if ~isempty(obj.PUSCHPDU)
                txSlotGrid = populatePUSCH(obj, obj.PUSCHPDU, obj.MacPDU, txSlotGrid, currentTime);
                if obj.PUSCHPDU.PUSCHConfig.SymbolAllocation(2) > numTxSymbols
                    numTxSymbols = obj.PUSCHPDU.PUSCHConfig.SymbolAllocation(2);
                end
            end
            
            % OFDM modulation
            txWaveform = nrOFDMModulate(carrier, txSlotGrid);
            
            % Trim txWaveform to span only the transmission symbols
            slotNumSubFrame = mod(obj.CurrSlot, obj.WaveformInfoUL.SlotsPerSubframe);
            startSymSubframe = slotNumSubFrame*obj.WaveformInfoUL.SymbolsPerSlot + 1; % Start symbol of current slot in the subframe
            lastSymSubframe = startSymSubframe + obj.WaveformInfoUL.SymbolsPerSlot -1; % Last symbol of current slot in the subframe
            symbolLengths = obj.WaveformInfoUL.SymbolLengths(startSymSubframe : lastSymSubframe); % Length of symbols of current slot
            startSample = sum(symbolLengths(1:obj.CurrSymbol)) + 1;
            endSample = sum(symbolLengths(1:obj.CurrSymbol+numTxSymbols));
            txWaveform = txWaveform(startSample:endSample, :);

            % Apply Tx power
            signalAmp = db2mag(obj.TxPower-30)*sqrt(obj.WaveformInfoUL.Nfft^2/(size(txSlotGrid, 1)*obj.NumTxAnts));
            
            % Construct packet information
            packetInfo.Waveform = signalAmp*txWaveform;
            packetInfo.RNTI = obj.RNTI;
            packetInfo.Position = obj.Node.Position;
            packetInfo.CarrierFreq = obj.CarrierInformation.ULFreq;
            packetInfo.SampleRate = obj.WaveformInfoUL.SampleRate;
            packetInfo.NCellID = obj.CellConfig.NCellID;
            
            % Waveform transmission by sending it to packet
            % distribution entity
            obj.SendPacketFcn(packetInfo);
            
            % Clear the Tx contexts
            obj.PUSCHPDU = {};
            obj.MacPDU = {};
        end
        
        function storeReception(obj, waveformInfo, currentTime)
            %storeReception Receive the waveform and add it to the reception
            % buffer

            % Don't process the packets that are not transmitted on the
            % receiver frequency
            if waveformInfo.CarrierFreq ~= obj.CarrierInformation.DLFreq
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
            pdschInfo = obj.DataRxContext{symbolNumFrame + 1};
            csirsInfo = obj.CSIRSContext{symbolNumFrame + 1};
            
            if isempty(pdschInfo) && isempty(csirsInfo)
                return; % No packet is scheduled to be read at the current symbol
            end

            rxDuration = 0; % In microseconds
            % Calculate the reception duration
            if ~isempty(pdschInfo)
                startSymPDSCH = pdschInfo.PDSCHConfig.SymbolAllocation(1);
                numSymPDSCH = pdschInfo.PDSCHConfig.SymbolAllocation(2);
                % Calculate the symbol start index w.r.t start of 1 ms sub frame
                slotNumSubFrame = mod(pdschInfo.NSlot, obj.WaveformInfoDL.SlotsPerSubframe);
                pdschSymbolSet = startSymPDSCH : startSymPDSCH+numSymPDSCH-1;
                symbolSetSubFrame = (slotNumSubFrame * 14) + pdschSymbolSet + 1;
                rxDuration = 1e6 * (1/obj.WaveformInfoDL.SampleRate) * ...
                    sum(obj.WaveformInfoDL.SymbolLengths(symbolSetSubFrame)); % In microseconds
            end
            
            if ~isempty(csirsInfo)
                % The CSI-RS which is currently being read was sent in the
                % last slot. Read the complete last slot
                %duration = 1e6 * (1e-3 / obj.WaveformInfoDL.SlotsPerSubframe);  % In microseconds
                
                % Calculate the symbol start index w.r.t start of 1 ms sub frame
                if obj.CurrSlot > 0
                    txSlot = obj.CurrSlot-1;
                else
                    txSlot = obj.WaveformInfoDL.SlotsPerSubframe*10-1;
                end
                slotNumSubFrame = mod(txSlot, obj.WaveformInfoDL.SlotsPerSubframe);
                symbolSet = 0:13;
                symbolSetSubFrame = (slotNumSubFrame * 14) + symbolSet + 1;
                rxDuration = 1e6 * (1/obj.WaveformInfoDL.SampleRate) * ...
                    sum(obj.WaveformInfoDL.SymbolLengths(symbolSetSubFrame)); % In microseconds
                
            end
           
            % Convert channel delay into microseconds
            maxChannelDelay = 1e6 * (1/obj.WaveformInfoDL.SampleRate) * obj.MaxChannelDelay;
            
            % Get the received waveform
            rxDuration = rxDuration + maxChannelDelay;
            rxWaveform = getReceivedWaveform(obj.RxBuffer, (currentTime*1e-3) + maxChannelDelay - rxDuration, rxDuration, obj.WaveformInfoDL.SampleRate);

            % Apply receiver antenna gain
            rxWaveform = applyRxGain(obj, rxWaveform);

            % Add thermal noise to the waveform
            rxWaveform = applyThermalNoise(obj, rxWaveform);
            
            % Process the waveform and send the decoded information to MAC
            phyRxProcessing(obj, rxWaveform, pdschInfo, csirsInfo, currentTime);
           
            % Clear the Rx contexts
            obj.DataRxContext{symbolNumFrame + 1} = {};
            obj.CSIRSContext{symbolNumFrame + 1} = {};
            obj.DataRxTime(symbolNumFrame+1) = Inf;
        end
    end
    
    methods (Access = private)
        function setWaveformProperties(obj, carrierInformation)
            %setWaveformProperties Set the UL and DL waveform properties
            %   setWaveformProperties(OBJ, CARRIERINFORMATION) sets the UL
            %   and DL waveform properties ae per the information in
            %   CARRIERINFORMATION. CARRIERINFORMATION is a structure
            %   including the following fields:
            %       SubcarrierSpacing  - Subcarrier spacing used
            %       NRBsDL             - Downlink bandwidth in terms of number of resource blocks
            %       NRBsUL             - Uplink bandwidth in terms of number of resource blocks
            
            % Set the UL waveform properties
            obj.WaveformInfoUL = nrOFDMInfo(carrierInformation.NRBsUL, carrierInformation.SubcarrierSpacing);
            
            % Set the DL waveform properties
            obj.WaveformInfoDL = nrOFDMInfo(carrierInformation.NRBsDL, carrierInformation.SubcarrierSpacing);
        end
        
        function updatedSlotGrid = populatePUSCH(obj, puschInfo, macPDU, txSlotGrid, currentTime)
            %populatePUSCH Populate PUSCH symbols in the Tx grid and return the updated grid
            
            % Set transport block in the encoder. In case of empty MAC PDU
            % sent from MAC (indicating retransmission), no need to set
            % transport block as it is already buffered in UL-SCH encoder
            % object
            if ~isempty(macPDU)
                % A non-empty MAC PDU is sent by MAC which indicates new
                % transmission
                macPDUBitmap = int2bit(macPDU, 8);
                macPDUBitmap = reshape(macPDUBitmap', [], 1); % Convert to column vector
                setTransportBlock(obj.ULSCHEncoder, macPDUBitmap, puschInfo.HARQID);
            end
            
            if ~isempty(obj.PacketLogger) % Packet capture enabled
                % Log uplink packets
                if isempty(macPDU)
                    tbID = 0; % Transport block id
                    macPDUBitmap = getTransportBlock(obj.ULSCHEncoder, tbID, puschInfo.HARQID);
                    macPDU = bit2int(macPDUBitmap, 8);
                end
                logPackets(obj, puschInfo, macPDU, 1, currentTime)
            end
            
            % Calculate PUSCH and DM-RS information
            carrierConfig = nrCarrierConfig;
            carrierConfig.NSizeGrid = obj.CarrierInformation.NRBsUL;
            carrierConfig.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrierConfig.NSlot = puschInfo.NSlot;
            carrierConfig.NCellID = obj.CellConfig.NCellID;
            [puschIndices, puschIndicesInfo] = nrPUSCHIndices(carrierConfig, puschInfo.PUSCHConfig);
            dmrsSymbols = nrPUSCHDMRS(carrierConfig, puschInfo.PUSCHConfig);
            dmrsIndices = nrPUSCHDMRSIndices(carrierConfig, puschInfo.PUSCHConfig);
            
            % UL-SCH encoding
            obj.ULSCHEncoder.TargetCodeRate = puschInfo.TargetCodeRate;
            codedTrBlock = obj.ULSCHEncoder(puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, ...
                puschIndicesInfo.G, puschInfo.RV, puschInfo.HARQID);
            
            % PUSCH modulation
            puschSymbols = nrPUSCH(carrierConfig, puschInfo.PUSCHConfig, codedTrBlock);
            
            % PUSCH mapping in the grid
            txSlotGrid(puschIndices) = puschSymbols;
            
            % PUSCH DM-RS mapping
            txSlotGrid(dmrsIndices) = dmrsSymbols;
            
            updatedSlotGrid = txSlotGrid;
        end
        
        function rxWaveform = applyChannelModel(obj, pktInfo, currentTime)
            %applyChannelModel Return the waveform after applying channel model
            fprintf("ID:%u RNTI:%u AFN:%u Slot:%u Sym:%u Time:%u wvFrmLgth:%u \n",...
                obj.Node.ID,obj.Node.MACEntity.RNTI,obj.AFN,obj.CurrSlot,obj.CurrSymbol,currentTime,length(pktInfo.Waveform))
            rxWaveform = pktInfo.Waveform;
            % Check if channel model is specified between UE and its gNB
            if ~isempty(obj.ChannelModel) && pktInfo.NCellID == obj.CellConfig.NCellID && ~isfield(pktInfo, 'RNTI')
                rxWaveform = [rxWaveform; zeros(obj.MaxChannelDelay, size(rxWaveform,2))];
                obj.ChannelModel.InitialTime = 1e-9*currentTime; % seconds
                rxWaveform = obj.ChannelModel(rxWaveform);
            else
                % Channel matrix to map the waveform from NumTxAnts to
                % NumRxAnts in the absence of CDL channel model
                numTxAnts = size(rxWaveform, 2);
                H = fft(eye(max([numTxAnts obj.NumRxAnts])));
                H = H(1:numTxAnts,1:obj.NumRxAnts);
                H = H / norm(H);
                rxWaveform = rxWaveform * H;
            end
            
            % Apply path loss on the waveform        
            distance = getNodeDistance(obj.Node, pktInfo.Position); % Calculate the distance between source and destination nodes
            lambda = physconst('LightSpeed')/pktInfo.CarrierFreq; % Wavelength
            % Calculate the path loss
            pathLoss = fspl(distance, lambda);
            rxWaveform = db2mag(-pathLoss)*rxWaveform;
        end
        
        function phyRxProcessing(obj, rxWaveform, pdschInfo, csirsInfo, currentTime)
            %phyRxProcessing Process the waveform and send the decoded information to MAC
            
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsDL;
            
            % Get the Tx slot
            if obj.CurrSymbol ==0 % Current symbol is first in the slot hence transmission was done in the last slot
                if obj.CurrSlot > 0
                    txSlot = obj.CurrSlot-1;
                    txSlotAFN = obj.AFN; % Tx slot was in the current frame
                else
                    txSlot = obj.WaveformInfoDL.SlotsPerSubframe*10-1;
                    % Tx slot was in the previous frame
                    txSlotAFN = obj.AFN - 1;
                end
                lastSym = obj.WaveformInfoDL.SymbolsPerSlot-1; % Last symbol number of the waveform
            else % Transmission was done in the current slot
                txSlot = obj.CurrSlot;
                txSlotAFN = obj.AFN; % Tx slot was in the current frame
                lastSym = obj.CurrSymbol - 1; % Last symbol number of the waveform
            end
            if ~isempty(csirsInfo)
                startSym = 0; % Read full slot
            else
                % Read from PDSCH start symbol
                startSym = lastSym - pdschInfo.PDSCHConfig.SymbolAllocation(2) + 1;
            end
            
            carrier.NSlot = txSlot;
            carrier.NFrame = txSlotAFN;
            
            % Populate the the received waveform at appropriate indices in the slot-length waveform
            slotNumSubFrame = mod(txSlot, obj.WaveformInfoDL.SlotsPerSubframe);
            startSampleIndexSlot = slotNumSubFrame*obj.WaveformInfoDL.SymbolsPerSlot + 1; % Start sample index of tx slot w.r.t start of subframe
            endSampleIndexSlot = startSampleIndexSlot + obj.WaveformInfoDL.SymbolsPerSlot -1; % End sample index of tx slot w.r.t start of subframe
            symbolLengths = obj.WaveformInfoDL.SymbolLengths(startSampleIndexSlot : endSampleIndexSlot); % Length of symbols of tx slot
            slotWaveform = zeros(sum(symbolLengths) + obj.MaxChannelDelay, obj.NumRxAnts);
            startIndex = sum(symbolLengths(1 : startSym))+1;  % Calculate the symbol start index w.r.t start of 1 ms subframe
            slotWaveform(startIndex : startIndex+length(rxWaveform)-1, :) = rxWaveform;

            % Calculate timing offset
            if ~isempty(pdschInfo) % If PDSCH is scheduled to be received in the waveform
                % Calculate PDSCH and DM-RS information
                carrier.NCellID = obj.CellConfig.NCellID;
                [pdschIndices, ~] = nrPDSCHIndices(carrier, pdschInfo.PDSCHConfig);
                dmrsSymbols = nrPDSCHDMRS(carrier, pdschInfo.PDSCHConfig);
                dmrsIndices = nrPDSCHDMRSIndices(carrier, pdschInfo.PDSCHConfig);
                % Calculate timing offset
                [t, mag] = nrTimingEstimate(carrier, slotWaveform, dmrsIndices, dmrsSymbols);
                obj.TimingOffset = hSkipWeakTimingOffset(obj.TimingOffset, t, mag);
            else
                % If only CSI-RS is present in the waveform
                csirsInd = nrCSIRSIndices(carrier, csirsInfo{1});
                csirsSym = nrCSIRS(carrier, csirsInfo{1});
                % Calculate timing offset
                [t, mag] = nrTimingEstimate(carrier, slotWaveform, csirsInd, csirsSym);
                obj.TimingOffset = hSkipWeakTimingOffset(obj.TimingOffset, t, mag);
            end
            
            if obj.TimingOffset > obj.MaxChannelDelay
                % Ignore the timing offset estimate resulting from weak correlation
                obj.TimingOffset = 0;
            end
            slotWaveform = slotWaveform(1+obj.TimingOffset:end, :);
            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGrid = nrOFDMDemodulate(carrier, slotWaveform);
            [K, L, R] = size(rxGrid);
            if (L < obj.WaveformInfoDL.SymbolsPerSlot)
                rxGrid = cat(2, rxGrid, zeros(K, obj.WaveformInfoDL.SymbolsPerSlot-L, R));
            end
            
            % Decode MAC PDU if PDSCH is present in waveform
            if ~isempty(pdschInfo)
                obj.DLSCHDecoder.TransportBlockLength = pdschInfo.TBS*8;
                obj.DLSCHDecoder.TargetCodeRate = pdschInfo.TargetCodeRate;
                [estChannelGrid, noiseEst] = nrChannelEstimate(rxGrid, dmrsIndices, dmrsSymbols, 'CDMLengths', pdschInfo.PDSCHConfig.DMRS.CDMLengths);
                % Get PDSCH resource elements from the received grid
                [pdschRx, pdschHest] = nrExtractResources(pdschIndices, rxGrid, estChannelGrid);
                
                % Equalization
                [pdschEq, csi] = nrEqualizeMMSE(pdschRx,pdschHest, noiseEst);
                
                % PDSCH decoding
                [dlschLLRs, rxSymbols] = nrPDSCHDecode(pdschEq, pdschInfo.PDSCHConfig.Modulation, pdschInfo.PDSCHConfig.NID, ...
                    pdschInfo.PDSCHConfig.RNTI, noiseEst);
                
                % Scale LLRs by CSI
                csi = nrLayerDemap(csi); % CSI layer demapping
                
                cwIdx = 1;
                Qm = length(dlschLLRs{1})/length(rxSymbols{cwIdx}); % bits per symbol
                csi{cwIdx} = repmat(csi{cwIdx}.',Qm,1);   % expand by each bit per symbol
                dlschLLRs{cwIdx} = dlschLLRs{cwIdx} .* csi{cwIdx}(:);   % scale
                
                [decbits, crcFlag] = obj.DLSCHDecoder(dlschLLRs, pdschInfo.PDSCHConfig.Modulation, ...
                    pdschInfo.PDSCHConfig.NumLayers, pdschInfo.RV, pdschInfo.HARQID);
                
                if pdschInfo.RV == obj.RVSequence(end)
                    % The last redundancy version failed. Reset the soft
                    % buffer
                    resetSoftBuffer(obj.DLSCHDecoder, 0, pdschInfo.HARQID);
                end
                
                % Convert bit stream to byte stream
                macPDU = bit2int(decbits, 8);
                
                % Rx callback to MAC
                macPDUInfo = hNRRxIndicationInfo;
                macPDUInfo.RNTI = pdschInfo.PDSCHConfig.RNTI;
                macPDUInfo.TBS = pdschInfo.TBS;
                macPDUInfo.HARQID = pdschInfo.HARQID;
                obj.RxIndicationFcn(macPDU, crcFlag, macPDUInfo); % Send PDU to MAC
                
                % Increment the number of erroneous packets
                obj.DLBlkErr(1) = obj.DLBlkErr(1) + crcFlag;
                % Increment the total number of received packets
                obj.DLBlkErr(2) = obj.DLBlkErr(2) + 1;
                
                if ~isempty(obj.PacketLogger) % Packet capture enabled
                    logPackets(obj, pdschInfo, macPDU, 0, currentTime); % Log DL packets
                end
            end
            
            csirsInfoList = csirsInfo;
            for idx=1:length(csirsInfoList)
                csirsInfo = csirsInfoList{idx};
                % If CSI-RS is present in waveform, measure RI, PMI and CQI
                if length(csirsInfo.RowNumber) == 1
                    csirsSym = nrCSIRS(carrier, csirsInfo);
                    csirsRefInd = nrCSIRSIndices(carrier, csirsInfo);
                    if ~isempty(csirsRefInd)
                        cdmType = csirsInfo.CDMType;
                        if ~iscell(csirsInfo.CDMType)
                            cdmType = {csirsInfo.CDMType};
                        end
                        mapping = containers.Map({'noCDM','FD-CDM2','CDM4','CDM8'},{[1 1],[2 1],[2 2],[2 4]});
                        cdmLen = mapping(cdmType{1});
                        % Estimated channel and noise variance
                        [Hest, nVar] = nrChannelEstimate(rxGrid, csirsRefInd, csirsSym, 'CDMLengths', cdmLen);

                        if obj.NumRxAnts > 1
                            rank = hRISelect(carrier, csirsInfo, obj.CSIReportConfig, Hest, nVar);
                            % Restricting the number of transmission layers to 4 as
                            % only single codeword is supported
                            rank = min(rank, 4);
                        else
                            rank = 1;
                        end
                        [cqi, pmiSet, ~, ~] = hCQISelect(carrier, csirsInfo, obj.CSIReportConfig, rank, Hest, nVar, obj.SINRTable);

                        % CQI value reported for each slot is stored in a new column
                        % In subband case, a column of CQI values is reported, where each element corresponds to each subband
                        % Convert CQI of sub-bands to per-RB CQI
                        cqiRBs = zeros(obj.CarrierInformation.NRBsDL, 1);
                        % Subband reporting is only applicable when number of RBs is more than 24
                        if strcmp(obj.CSIReportConfig.CQIMode, 'Subband') && (csirsInfo.NumRB > 24)
                            subbandSize = obj.CSIReportConfig.SubbandSize;
                            cqiOffsetLevel = [0 1 2 -1]; %  Corresponding to offset values (0, 1, 2 and 3) as per TS 38.214 Table 5.2.2.1-1
                            % Fill same CQI for all the RBs in the sub-band
                            for i = 1:obj.CarrierInformation.NRBsDL/subbandSize
                                cqiRBs((i-1)*subbandSize+1 : i*subbandSize) = cqi(1) + cqiOffsetLevel(cqi(i+1)+1);
                            end
                            if mod(obj.CarrierInformation.NRBsDL, subbandSize)
                                cqiRBs((length(cqi)-2)*subbandSize+1 : end) = cqi(1) + cqiOffsetLevel(cqi(end)+1);
                            end
                        else
                            cqiRBs(:) = cqi(1); % Wideband CQI
                        end
                        cqiRBs(cqiRBs<=1) = 1; % Ensuring minimum CQI as 1

                        % Report the CQI to MAC
                        obj.CSIRSIndicationFcn(rank, pmiSet, cqiRBs);
                    end
                end
                % CSI-RS resource set for L1-RSRP measurement
                if length(csirsInfo.RowNumber) > 1
                    csiMeasurement = nrCSIRSMeasurements(carrier,csirsInfo,rxGrid);
                    [l1RSRP, cri] = max(max(csiMeasurement.RSRPPerAntenna,[],1));
                    obj.CSIRSIndicationFcn(cri, l1RSRP);
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
            Nt = physconst('Boltzmann')*(obj.AntNoiseTemperature + 290*(noiseFigure-1))*obj.WaveformInfoDL.SampleRate;
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
                obj.PacketMetaData.SystemFrameNumber = mod(obj.AFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Uplink;
            else % Downlink
                % Get frame number of previous slot i.e the Tx slot. Reception ended at the
                % end of previous slot
                if obj.CurrSlot > 0
                    prevSlotAFN = obj.AFN; % Previous slot was in the current frame
                else
                    % Previous slot was in the previous frame
                    prevSlotAFN = obj.AFN - 1;
                end
                obj.PacketMetaData.SystemFrameNumber = mod(prevSlotAFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Downlink;
            end
            write(obj.PacketLogger, macPDU, round(currentTime*1e-3), 'PacketInfo', obj.PacketMetaData);
        end

        function nextInvokeTime = getNextInvokeTime(obj, currentTime)
            %getNextInvokeTime Return the next invoke time in nanoseconds

            % Find the next invoke time for CSI-RS reception
            if obj.NextCSIRSRxTime > currentTime
                csirsRxNextInvokeTime = obj.NextCSIRSRxTime;
            else
                csirsRxNextInvokeTime = Inf;
            end

            % Find the next PHY Rx invoke time
            pdschRxNextInvokeTime = min(obj.DataRxTime);

            nextInvokeTime = min([pdschRxNextInvokeTime csirsRxNextInvokeTime]);
        end
    end

    methods (Hidden = true)
        function dlTTIRequest(obj, pduType, dlControlPDU)
            dlControlRequest(obj, pduType, dlControlPDU);
        end
    end
end