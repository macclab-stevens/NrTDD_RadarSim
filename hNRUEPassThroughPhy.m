classdef hNRUEPassThroughPhy < hNRPhyInterface
    %hNRUEPassThroughPhy Implements a pass-through UE physical layer without any physical layer processing
    %   The class implements a pass-through Phy at UE. It implements the
    %   interfaces for information exchange between Phy and higher layers.
    %   It implements the periodic channel update mechanism by varying the
    %   assumed CQI values. Packet reception errors are modeled in a
    %   probabilistic manner.
    
    %   Copyright 2020-2022 The MathWorks, Inc.

    properties
        %DLBlkErr Downlink block error information
        % It is an array of two elements containing the number of
        % erroneously received packets and total received packets,
        % respectively
        DLBlkErr
    end
    
    properties (Access = private)
        
        %RNTI RNTI of UE
        RNTI
        
        %HarqBuffers Buffers to store uplink HARQ transport blocks
        % Cell array of 16 elements to buffer transport blocks of different
        % HARQ processes. The physical layer buffers the transport blocks
        % for retransmissions
        HARQBuffers
        
        %PUSCHPDU PUSCH information sent by MAC for the current slot
        % It is an object of type hNRPUSCHInfo. It contains the information
        % required by Phy to transmit a MAC PDU stored object property
        % 'MacPDU'
        PUSCHPDU = {}
        
        %MacPDU PDU sent by MAC which is scheduled to be sent in the current slot
        % The uplink MAC PDU to be sent in the current
        % slot using information in object property PUSCHPDU
        MacPDU = {}
        
        %CSIRSContext Rx context for the CSI-RS
        % Cell array of size 'N' where N is the number of symbols in a 10 ms
        % frame. The cell elements are populated with objects of type
        % nrCSIRSConfig. An element at index 'i' contains the CSI-RS
        % configuration which is sent in the symbol index 'i-14' (i.e
        % '(i-1)/14)' slot). Cell element at 'i' is empty if no CSI-RS
        % reception was scheduled in the symbol 'i-14'
        CSIRSContext
        
        %CSIRSIndicationFcn Function handle to send the DL channel quality to MAC
        CSIRSIndicationFcn
        
        %RxBuffer Rx buffer to store incoming DL packets
        % Cell array of length 'N' where 'N' is the number of symbols in a 10
        % ms frame. An element at index 'i' buffers the packet
        % received, whose reception starts at symbol index 'i' in the frame
        RxBuffer
        
        %ChannelQualityDL Current DL channel quality
        ChannelQualityDL
        
        %CQIvsDistance CQI vs Distance mapping
        % It is matrix with 2 columns. Each row is a mapping between
        % distance from gNB (first column in meters) and maximum achievable
        % DL CQI value (second column)
        CQIvsDistance = [
            200  15;
            500  12;
            800  10;
            1000  8;
            1200  7];
        
        %ChannelUpdatePeriodicityInSlots Channel update periodicity in terms of number of slots
        ChannelUpdatePeriodicityInSlots = 100;
        
        %CQIDelta Amount by which CQI improves/deteriorates every ChannelUpdatePeriodicity slots
        CQIDelta = 1;
        
        %ChannelUpdatePeriodicity Channel update periodicity in seconds
        ChannelUpdatePeriodicity = 0;
        
        %GNBPosition Position of gNB
        % Assumed DL CQI values are based on distance to gNB
        GNBPosition = [0 0 0];
        
        %PacketLogger Contains handle of the PCAP object
        PacketLogger
        
        %PacketMetaData Contains the information required for logging MAC
        %packets into PCAP
        PacketMetaData

        %NextCSIRSRxTime Next CSI-RS reception time in nanoseconds
        NextCSIRSRxTime = -1
    end
    
    methods
        function obj = hNRUEPassThroughPhy(param, rnti)
            %hNRUEPassThroughPhy Construct a UE pass-through Phy object
            % OBJ = hNRUEPassThroughPhy(RNTI, PARAM) constructs a UE Phy object.
            %
            % PARAM is a structure with SCS and the fields to define the
            % way channel updates happen in the absence of actual channel.
            % It contain these fields:
            %   SCS                        - Subcarrier spacing
            %   CQIvsDistance              - CQI vs Distance mapping
            %   ChannelUpdatePeriodicity   - Periodicity of channel update in seconds
            %   CQIDelta                   - Amount by which CQI value
            %                                improves/deteriorates every time
            %                                channel updates
            %   NumRBs                     - Number of RBs in DL bandwidth
            %   GNBPosition                - Position of gNB
            %   InitialChannelQualityDL    - Initial DL channel quality for the UE
            %
            %   CQIvsDistance is a mapping between distance from gNB (first
            %   column in meters) and maximum achievable CQI value (second
            %   column). For example, if a UE is 700 meters away from the
            %   gNB, it can achieve a maximum CQI value of 10 as the distance
            %   falls within the [501, 800] meters range, as per the below
            %   sample mapping.
            %   CQIvsDistance = [
            %       200  15;
            %       500  12;
            %       800  10;
            %       1000  8;
            %       1200  7];
            %   Channel quality is periodically improved or deteriorated by
            %   CQIDelta every ChannelUpdatePeriodicity seconds for all RBs
            %   of a UE. Whether channel conditions for a particular UE
            %   improve or deteriorate is randomly determined
            %
            % RNTI is the RNTI of UE
            
            % Validate the subcarrier spacing
            if ~ismember(param.SCS, [15 30 60 120 240])
                error('nr5g:hNRUEPassThroughPhy:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120, 240).', param.SCS);
            end
            
            % Validate number of RBs
            validateattributes(param.NumRBs, {'numeric'}, {'real', 'integer', 'scalar', '>=', 1, '<=', 275}, 'param.NumRBs', 'NumRBs');
            
            % Validate rnti
            validateattributes(rnti, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 1, '<=', 65519}, 'rnti');
            
            obj.HARQBuffers = cell(1, 16); % HARQ buffers
            obj.RNTI = rnti;
            obj.CSIRSContext = cell(10*(param.SCS/15)*14, 1);  % Create the context for all the symbols in the frame
            
            if isfield(param, 'InitialChannelQualityDL')
                % Validate initial channel quality in the downlink
                % direction
                validateattributes(param.InitialChannelQualityDL(rnti, :), {'numeric'}, {'integer', 'nonempty', '>=', 1, '<=', 15}, 'InitialChannelQualityDL');
                obj.ChannelQualityDL = param.InitialChannelQualityDL(rnti, :);
            else
                % Initialize the CQI to 7 for the DL bandwidth for the UE
                initialCQI = 7;
                obj.ChannelQualityDL = initialCQI*ones(param.NumRBs, 1);
            end
            
            if isfield(param, 'CQIvsDistance')
                % Validate the mapping between distance and CQI. Distance
                % must be in strictly increasing order
                validateattributes(param.CQIvsDistance, {'numeric'}, {'nonempty', '2d'}, 'param.CQIvsDistance', 'CQIvsDistance');
                % Distance must be in strictly increasing order
                validateattributes(param.CQIvsDistance(:, 1), {'numeric'}, {'finite', '>', 0, 'increasing'}, 'param.CQIvsDistance(:, 1)');
                obj.CQIvsDistance = param.CQIvsDistance;
            end
            
            if isfield(param, 'CQIDelta')
                % Validate the channel improvement or deterioration value
                validateattributes(param.CQIDelta, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'param.CQIDelta', 'CQIDelta');
                obj.CQIDelta = param.CQIDelta;
            end
            
            if isfield(param, 'ChannelUpdatePeriodicity')
                % Validate the channel update periodicity
                validateattributes(param.ChannelUpdatePeriodicity, {'numeric'}, {'nonempty', 'finite', 'scalar', '>', 0}, 'param.ChannelUpdatePeriodicity', 'ChannelUpdatePeriodicity');
                obj.ChannelUpdatePeriodicity = param.ChannelUpdatePeriodicity;
            else
                obj.ChannelUpdatePeriodicity = obj.ChannelUpdatePeriodicityInSlots * (15e-3/param.SCS);
            end
            
            % Set the number of erroneous packets and total number of
            % packets received by the UE to zero
            obj.DLBlkErr = zeros(1, 2);
            
            % Initialize Rx buffer
            symbolsPerFrame = 14*10*(param.SCS/15);
            obj.RxBuffer = cell(symbolsPerFrame, 1);
            
            if isfield(param, 'GNBPosition')
                % Validate gNB position
                validateattributes(param.GNBPosition, {'numeric'}, {'numel', 3, 'nonempty', 'finite', 'nonnan', '>=', 0}, 'param.GNBPosition', 'GNBPosition');
                obj.GNBPosition = param.GNBPosition;
            end

            if isfield(param, 'UETxAnts') && param.UETxAnts ~= 1
               error('nr5g:hNRUEPassThroughPhy:InvalidTxAntennaSize', 'Number of UE transmit antenna elements must be equal to 1 for passthrough Phy');
            end
            if isfield(param, 'UERxAnts') && param.UERxAnts ~= 1
               error('nr5g:hNRUEPassThroughPhy:InvalidRxAntennaSize', 'Number of UE receive antenna elements must be equal to 1 for passthrough Phy');
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

                if mod(currentTime, obj.ChannelUpdatePeriodicity*1e9) == 0
                    updateCQI(obj);
                end
            end

            % Phy transmission of MAC PDUs without any Phy processing. It
            % is assumed that MAC has already loaded the Phy Tx context for
            % anything scheduled to be transmitted at the current time
            phyTx(obj, currentTime);

            % Store the received packet
            for pktIdx = 1:numel(packets)
                if ~isfield(packets{pktIdx}, 'PacketType')
                    storeReception(obj, packets{pktIdx});
                end
            end

            % Phy reception and sending the PDU to MAC. Reception of MAC
            % PDU is done in the symbol after the last symbol in PDSCH
            % duration (till then the packets are queued in Rx buffer). Phy
            % calculates the last symbol of PDSCH duration based on
            % 'rxDataRequest' call from MAC (which comes at the first
            % symbol of PDSCH Rx time) and the PDSCH duration
            phyRx(obj, currentTime);


            % Get the next invoke time for PHY
            nextInvokeTime = getNextInvokeTime(obj, currentTime);
            % Update the last run time
            obj.LastRunTime = currentTime;
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
        
        function updateCQI(obj)
            %updateCQI Update the channel quality
            %   updateCQI(OBJ) updates the channel quality.

            % Update the channel conditions
            disToGNB = getNodeDistance(obj.Node, obj.GNBPosition);
            % Get achievable CQI based on the current distance of UE from
            % gNB
            matchingRowIdx = find(obj.CQIvsDistance(:, 1) > disToGNB);
            if isempty(matchingRowIdx)
                maxCQI = obj.CQIvsDistance(end, 2);
            else
                maxCQI = obj.CQIvsDistance(matchingRowIdx(1), 2);
            end
            updateType = [1 -1]; % Update type: Improvement/deterioration
            channelQualityChange = updateType(randi(length(updateType)));
            % Update the channel quality
            currentCQIRBs = obj.ChannelQualityDL;
            obj.ChannelQualityDL = min(max(currentCQIRBs + obj.CQIDelta*channelQualityChange, 1), maxCQI);
        end
        
        function txDataRequest(obj, PUSCHInfo, macPDU, ~)
            %txDataRequest Data Tx request from MAC to Phy for starting PUSCH transmission
            %  txDataRequest(OBJ, PUSCHINFO, MACPDU) sets the Tx context to
            %  indicate PUSCH transmission in the current slot
            %
            %  PUSCHInfo is an object of type hNRPUSCHInfo sent by MAC. It
            %  contains the information required by the Phy for the
            %  transmission.
            %
            %  MACPDU is the uplink MAC PDU sent by MAC for transmission.
            
            obj.MacPDU = macPDU;
            obj.PUSCHPDU = PUSCHInfo;
        end
        
        function rxDataRequest(obj, pdschInfo, timingInfo)
            %rxDataRequest Rx request from MAC to Phy for starting PDSCH reception
            %   rxDataRequest(OBJ, PDSCHINFO, TIMINGINFO) is a request to
            %   start PDSCH reception. It starts a timer for PDSCH end time
            %   (which on firing receives the PDSCH).
            %
            %   PDSCHInfo is an object of type hNRPDSCHInfo. It
            %   contains the information required by the Phy for the
            %   reception.
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     CurrSlot   - Current slot number in a 10 millisecond frame
            %     CurrSymbol - Current symblo number in the current slot
            %     Timestamp  - Reception start timestamp in nanoseconds.

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
        
        function dlControlRequest(obj, pduType, dlControlPDU, timingInfo)
            %dlControlRequest Downlink control request from MAC to Phy
            %   dlControlRequest(OBJ, PDUTYPES, DLCONTROLPDUS, TIMIINGINFO)
            %   is a request to start downlink receptions. MAC sends it at
            %   the start of a DL slot for all the scheduled DL receptions
            %   in the slot (except PDSCH, which is received using
            %   rxDataRequest interface of this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only
            %   packet type 0 (CSI-RS) is supported.
            %
            %   DLCONTROLPDU is an array of DL control PDUs corresponding
            %   to packet types in PDUTYPE. Currently supported CSI-RS PDU
            %   is an object of type nrCSIRSConfig. Pass-through phy does
            %   not send/receive actual CSI-RS. It is just a request from
            %   MAC to report the current assumed channel quality (as per
            %   the installed channel update mechanism)
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     Slot      - Current slot number in a 10 millisecond frame
            %     Symbol    - Current symblo number in the current slot
            %     Timestamp - Reception start timestamp in nanoseconds.

            % Update the Rx context for DL receptions
            for i=1:length(pduType)
                switch(pduType(i))
                    case obj.CSIRSPDUType
                        % Channel quality would be read at the end of the current slot
                        currSlot = mod(timingInfo.CurrSlot, obj.CarrierInformation.SlotsPerSubframe*10);
                        rxSymbolFrame = (currSlot+1) * 14;
                        obj.CSIRSContext{rxSymbolFrame} = dlControlPDU{i};
                        obj.NextCSIRSRxTime = timingInfo.Timestamp + obj.CarrierInformation.SlotDuration; % In nanoseconds
                end
            end
        end
        
        function ulControlRequest(~, ~, ~, ~)
            %ulControlRequest Uplink control request from MAC to Phy
            
            % Not required for UE pass-through Phy. Overriding the
            % abstract method of the base class to do nothing
        end
        
        function registerMACInterfaceFcn(obj, sendMACPDUFcn, sendDLChanQualityFcn)
            %registerMACInterfaceFcn Register MAC interface functions at Phy for sending information to MAC
            %   registerMACInterfaceFn(OBJ, SENDMACPDUFCN,
            %   SENDDLCHANQUALITYFCN) registers the callback function to
            %   send PDUs and DL channel quality to MAC.
            %
            %   SENDMACPDUFCN Function handle provided by MAC to Phy for
            %   sending PDUs.
            %
            %   SENDDLCHANQUALITYFCN Function handle provided by MAC to Phy for
            %   sending the measured DL channel quality.
            
            obj.RxIndicationFcn = sendMACPDUFcn;
            obj.CSIRSIndicationFcn = sendDLChanQualityFcn;
        end
        
        function  phyTx(obj, currentTime)
            %phyTx Physical layer transmission of scheduled PUSCH
            %
            % CURRENTTIME - Current time in nanoseconds

            if ~isempty(obj.PUSCHPDU) % If any UL MAC PDU is scheduled to be sent now
                if isempty(obj.MacPDU)
                    % MAC PDU not sent by MAC. Indicates retransmission. Get
                    % the MAC PDU from the HARQ buffers
                    obj.MacPDU = obj.HARQBuffers{obj.PUSCHPDU.HARQID+1};
                else
                    % New transmission. Buffer the transport block
                    obj.HARQBuffers{obj.PUSCHPDU.HARQID+1} = obj.MacPDU;
                end
                % Transmit the transport block
                packetInfo.Packet = obj.MacPDU;
                packetInfo.NCellID = obj.CellConfig.NCellID;
                packetInfo.RNTI = obj.RNTI;
                packetInfo.CarrierFreq = obj.CarrierInformation.ULFreq;
                obj.SendPacketFcn(packetInfo);
                
                if ~isempty(obj.PacketLogger) % Packet capture enabled
                    logPackets(obj, obj.PUSCHPDU, obj.MacPDU, 1, currentTime); % Log UL packets
                end
            end
            
            % Transmission done. Clear the Tx contexts
            obj.PUSCHPDU = {};
            obj.MacPDU = {};
        end
        
        function phyRx(obj, currentTime)
            %phyRx Physical layer reception
            %
            % CURRENTTIME - Current time in nanoseconds

            symbolNumFrame = mod(obj.CurrSlot*14 + obj.CurrSymbol- 1, obj.CarrierInformation.SymbolsPerFrame); % Previous symbol number in a 10 ms frame
            pdschInfo = obj.DataRxContext{symbolNumFrame + 1};
            if ~isempty(pdschInfo) % If a PDSCH ended in the last symbol
                pdschRx(obj, pdschInfo, currentTime); % Read the MAC PDU corresponding to PDSCH and send it to MAC
                obj.DataRxContext{symbolNumFrame + 1} = {}; % Clear the context
                obj.DataRxTime(symbolNumFrame + 1) = Inf;
            end
            
            csirsInfo = obj.CSIRSContext{symbolNumFrame + 1};
            if ~isempty(csirsInfo)
                % Send the DL CQI to MAC
                obj.CSIRSIndicationFcn(1, [], obj.ChannelQualityDL);
                obj.CSIRSContext{symbolNumFrame + 1} = {}; % Clear the context
            end
        end
        
        function storeReception(obj, packetInfo)
            %storeReception Receive the incoming packet and add it to the reception buffer
            
            % Don't process the packets that are not transmitted on the
            % receiver frequency
            if packetInfo.CarrierFreq ~= obj.CarrierInformation.DLFreq
                return;
            end

            % Filter the other packets which are not directed to this UE
            if obj.CellConfig.NCellID == packetInfo.NCellID && packetInfo.RNTI == obj.RNTI
                symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number w.r.t start of 10 ms frame
                obj.RxBuffer{symbolNumFrame+1} = packetInfo.Packet; % Buffer the packet
            end
        end
    end

    methods (Access = private)
        function pdschRx(obj, pdschInfo, currentTime)
            %pdschRx Receive the MAC PDU corresponding to PDSCH and send it to MAC
            
            % Read packet from Rx buffer. It is stored at the symbol index
            % in 10 ms frame where the reception started
            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number w.r.t start of 10 ms frame
            
            % Calculate Rx start symbol number w.r.t start of the 10 ms frame
            if symbolNumFrame == 0 % Packet was received in the previous frame
                rxStartSymbol = obj.CarrierInformation.SymbolsPerFrame -  pdschInfo.PDSCHConfig.SymbolAllocation(2);
            else % Packet was received in the current frame
                rxStartSymbol = symbolNumFrame - pdschInfo.PDSCHConfig.SymbolAllocation(2);
            end
            
            macPDU = obj.RxBuffer{rxStartSymbol+1}; % Read the stored MAC PDU corresponding to PUSCH
            obj.RxBuffer{rxStartSymbol+1} = {}; % Clear the buffer
            
            crcFlag = crcResult(obj);
            
            % Increment the number of erroneous packets
            obj.DLBlkErr(1) = obj.DLBlkErr(1) + crcFlag;
            % Increment the total number of received packets
            obj.DLBlkErr(2) = obj.DLBlkErr(2) + 1;
            
            % Rx callback to MAC
            macPDUInfo = hNRRxIndicationInfo;
            macPDUInfo.RNTI = pdschInfo.PDSCHConfig.RNTI;
            macPDUInfo.TBS = pdschInfo.TBS;
            macPDUInfo.HARQID = pdschInfo.HARQID;
            obj.RxIndicationFcn(macPDU, crcFlag, macPDUInfo);
            
            if ~isempty(obj.PacketLogger) % Packet capture enabled
                logPackets(obj, pdschInfo, macPDU, 0, currentTime); % Log DL packets
            end
        end
        
        function crcFlag = crcResult(~)
            %crcFlag Calculate crc success/failure result
            
            successProbability = 0.9; % For 0.1 block error rate (BLER)
            if(rand(1) <= successProbability)
                crcFlag = 0; % No error
            else
                crcFlag = 1; % Error
            end
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
                if obj.CurrSlot == 0 && obj.CurrSymbol == 0
                    rxAFN = obj.AFN - 1; % Reception was in the previous frame
                else
                    rxAFN = obj.AFN; % Reception was in the current frame
                end
                obj.PacketMetaData.SystemFrameNumber = mod(rxAFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Downlink;
            end
            write(obj.PacketLogger, macPDU, round(currentTime*1e-3), 'PacketInfo', obj.PacketMetaData);
        end

        function nextInvokeTime = getNextInvokeTime(obj, currentTime)
            %getNextInvokeTime Return the next invoke time for PHY

            %  Find the next invoke time for CSI-RS reception
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