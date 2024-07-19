classdef hNRGNBPassThroughPhy < hNRPhyInterface
    %hNRGNBPassThroughPhy Implements a pass-through gNB physical layer without any physical layer processing
    %   The class implements a pass-through Phy at gNB. It implements the
    %   interfaces for information exchange between Phy and higher layers.
    %   Packet reception errors are modeled in a probabilistic manner
    
    %   Copyright 2020-2022 The MathWorks, Inc.

    properties
        %ULBlkErr Uplink block error information
        % It is an array of size N-by-2 where N is the number of UEs,
        % columns 1 and 2 contains the number of erroneously received
        % packets and total received packets, respectively.
        ULBlkErr
    end

    properties (Access = private)
        
        %UEs RNTIs in the cell
        UEs
        
        %HarqBuffers Buffers to store downlink HARQ transport blocks
        % N-by-16 cell array to buffer transport blocks for 16 HARQ
        % processes, where 'N' is the number of UEs. The physical layer
        % stores the transport blocks for retransmissions
        HARQBuffers
        
        %PDSCHPDU PDSCH information sent by MAC for the current slot
        % It is an array of objects of type hNRPDSCHInfo. An object at
        % index 'i' contains the information required by Phy to transmit a MAC
        % PDU stored at index 'i' of object property 'MacPDU'
        PDSCHPDU = {}
        
        %MacPDU PDUs sent by MAC which are scheduled to be sent in the current slot
        % It is an array of downlink MAC PDUs to be sent in the current
        % slot. Each object in the array corresponds to one object in
        % object property PDSCHPDU
        MacPDU = {}
        
        %RxBuffer Rx buffer to store incoming UL packets
        % N-by-P cell array where 'N' is number of symbols in a 10 ms frame
        % and 'P' is number of UEs served by cell. An element at index (i,
        % j) buffers the packet received from UE with RNTI 'j' and whose
        % reception starts at symbol index 'i' in the frame. Packet is read
        % from here in the symbol after the last symbol in the PUSCH
        % duration
        RxBuffer
        
        %PacketLogger Contains handle of the packet capture (PCAP) object
        PacketLogger
        
        %PacketMetaData Contains the information required for logging MAC packets into PCAP file
        PacketMetaData

        %NextSRSRxTime Next SRS reception time in nanoseconds
        NextSRSRxTime = -1
    end
    
    methods
        function obj = hNRGNBPassThroughPhy(param)
            %hNRGNBPassThroughPhy Construct a gNB pass-through Phy object
            % OBJ = hNRGNBPassThroughPhy(param) constructs a gNB Phy object.
            % PARAM is a structure with fields:
            %   NumUEs                     - Number of UEs connected to the gNB
            %   SCS                        - Subcarrier spacing
            %   NumRBs                     - Number of RBs in UL bandwidth
            
            % Validate the number of UEs
            validateattributes(param.NumUEs, {'numeric'}, {'nonempty', 'integer', 'scalar', 'finite', '>=', 0}, 'param.NumUEs', 'NumUEs');
            
            % Validate the subcarrier spacing
            if ~ismember(param.SCS, [15 30 60 120])
                error('nr5g:hNRGNBPassThroughPhy:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120).', param.SCS);
            end
            
            % Validate number of RBs
            validateattributes(param.NumRBs, {'numeric'}, {'real', 'integer', 'scalar', '>=', 1, '<=', 275}, 'param.NumRBs', 'NumRBs');

            if isfield(param, 'GNBTxAnts') && param.GNBTxAnts ~= 1
                error('nr5g:hNRGNBPassThroughPhy:InvalidTxAntennaSize', 'Number of gNB transmit antenna elements must be equal to 1 for passthrough Phy');
            end
            if isfield(param, 'GNBRxAnts') && param.GNBRxAnts ~= 1
                error('nr5g:hNRGNBPassThroughPhy:InvalidRxAntennaSize', 'Number of gNB receive antenna elements must be equal to 1 for passthrough Phy');
            end
            if isfield(param, 'UETxAnts') && any(param.UETxAnts ~= 1)
                error('nr5g:hNRGNBPassThroughPhy:InvalidUETxAntennaSize', 'Number of UE transmit antenna elements must be equal to 1 for passthrough Phy');
            end
            if isfield(param, 'UERxAnts') && any(param.UERxAnts ~= 1)
                error('nr5g:hNRGNBPassThroughPhy:InvalidUERxAntennaSize', 'Number of UE receive antenna elements must be equal to 1 for passthrough Phy');
            end
            
            obj.UEs = 1:param.NumUEs;
            obj.HARQBuffers = cell(length(obj.UEs), 16); % HARQ buffers for all the UEs
            
            % Set the number of erroneous packets and the total number of
            % packets received from each UE to zero
            obj.ULBlkErr = zeros(param.NumUEs, 2);
            
            % Initialize Rx buffer
            symbolsPerFrame = 14*10*(param.SCS/15);
            obj.RxBuffer = cell(symbolsPerFrame, length(obj.UEs));
        end
        
        function nextInvokeTime = run(obj, currentTime, packets)
            %run Run the gNB Phy layer operations and return the next invoke time (in nanoseconds)
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
            % PDU is done in the symbol after the last symbol in PUSCH
            % duration (till then the packets are queued in Rx buffer). Phy
            % calculates the last symbol of PUSCH duration based on
            % 'rxDataRequest' call from MAC (which comes at the first
            % symbol of PUSCH Rx time) and the PUSCH duration
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
        end
        
        function txDataRequest(obj, PDSCHInfo, macPDU, ~)
            %txDataRequest Tx request from MAC to Phy for starting PDSCH transmission
            %  txDataRequest(OBJ, PDSCHINFO, MACPDU) sets the Tx context to
            %  indicate PDSCH transmission in the current slot
            %
            %  PDSCHInfo is an object of type hNRPDSCHInfo, sent by MAC. It
            %  contains the information required by the Phy for the transmission.
            %
            %  MACPDU is the downlink MAC PDU sent by MAC for
            %  transmission.
            
            % Update the Tx context. There can be multiple simultaneous
            % PDSCH transmissions for different UEs
            obj.MacPDU{end+1} = macPDU;
            obj.PDSCHPDU{end+1} = PDSCHInfo;
        end
        
        function rxDataRequest(obj, puschInfo, timingInfo)
            %rxDataRequest Rx request from MAC to Phy for starting PUSCH reception
            %   rxDataRequest(OBJ, PUSCHINFO, TIMINGINFO) is a request to
            %   start PUSCH reception. It starts a timer for PUSCH end time
            %   (which on firing receives the PUSCH). The Phy expects the
            %   MAC to send this request at the start of reception time.
            %
            %   PUSCHInfo is an object of type hNRPUSCHInfo sent by MAC. It
            %   contains the information required by the Phy for the
            %   reception.
            %
            %
            %   TIMINGINFO is a structure that contains the following
            %   fields.
            %     CurrSlot   - Current slot number in a 10 millisecond frame
            %     CurrSymbol - Current symblo number in the current slot
            %     Timestamp - Reception start timestamp in nanoseconds.

            puschStartSym = puschInfo.PUSCHConfig.SymbolAllocation(1);
            symbolNumFrame = puschInfo.NSlot*14 + puschStartSym; % PUSCH Tx start symbol number w.r.t start of 10 ms frame
            
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
        
        function dlControlRequest(~, ~, ~, ~)
            %dlControlRequest Downlink control request from MAC to Phy
            
            % Not required for gNB pass-through Phy, as currently only data
            %(i.e. PDSCH) is supported. Overriding the abstract method of the
            % base class to do nothing
        end
        
        function ulControlRequest(~, ~, ~, ~)
            %ulControlRequest Uplink control request from MAC to Phy

            % Not required for gNB pass-through Phy. Overriding the
            % abstract method of the base class to do nothing
        end

        function registerMACInterfaceFcn(obj, sendMACPDUFcn, ~)
            %registerMACInterfaceFcn Register MAC interface functions at Phy for sending information to MAC
            %   registerMACInterfaceFcn(OBJ, SENDMACPDUFCN, ~) registers the
            %   function to send PDUs to MAC.
            %
            %   SENDMACPDUFCN Function handle provided by MAC to Phy, for
            %   sending PDUs
            
            obj.RxIndicationFcn = sendMACPDUFcn;
        end
 
        function phyTx(obj, currentTime)
            %phyTx Physical layer transmission
            %
            % CURRENTTIME - Current time in nanoseconds

            for i=1:length(obj.PDSCHPDU) % For each DL MAC PDU scheduled to be sent now
                if isempty(obj.MacPDU{i})
                    % MAC PDU not sent by MAC. Indicates retransmission. Get
                    % the MAC PDU from the HARQ buffers
                    obj.MacPDU{i} = obj.HARQBuffers{obj.PDSCHPDU{i}.PDSCHConfig.RNTI, obj.PDSCHPDU{i}.HARQID+1};
                else
                    % New transmission. Buffer the transport block
                    obj.HARQBuffers{obj.PDSCHPDU{i}.PDSCHConfig.RNTI, obj.PDSCHPDU{i}.HARQID+1} = obj.MacPDU{i};
                end
                % Transmit the transport block
                packetInfo.Packet = obj.MacPDU{i};
                packetInfo.NCellID = obj.CellConfig.NCellID;
                packetInfo.RNTI = obj.PDSCHPDU{i}.PDSCHConfig.RNTI;
                packetInfo.CarrierFreq = obj.CarrierInformation.DLFreq;
                obj.SendPacketFcn(packetInfo);
                
                if ~isempty(obj.PacketLogger) % Packet capture enabled
                    logPackets(obj, obj.PDSCHPDU{i}, obj.MacPDU{i}, 0, currentTime); % Log DL packets
                end
            end
            
            % Transmission done. Clear the Tx contexts
            obj.PDSCHPDU = {};
            obj.MacPDU = {};
        end
        
        function phyRx(obj, currentTime)
            %phyRx Physical layer reception
            %
            % CURRENTTIME - Current time in nanoseconds

            symbolNumFrame = mod(obj.CurrSlot*14 + obj.CurrSymbol - 1, obj.CarrierInformation.SymbolsPerFrame); % Previous symbol in a 10 ms frame
            puschInfo = obj.DataRxContext{symbolNumFrame+1};
            % For all receptions which ended in the last symbol, read the
            % MAC PDU corresponding to PUSCH and send it to MAC
            for i=1:length(puschInfo)
                puschRx(obj, puschInfo{i}, currentTime);
            end
            obj.DataRxContext{symbolNumFrame+1} = {}; % Clear the context
            obj.DataRxTime(symbolNumFrame+1) = Inf;
        end
        
        function storeReception(obj, packetInfo)
            %storeReception Receive the incoming packet and add it to the reception buffer
            
            % Filter out the packets from other cells
            if obj.CellConfig.NCellID == packetInfo.NCellID
                % Current symbol number w.r.t start of 10 ms frame
                symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
                % Buffer the packet. It would be read after the reception
                % end time
                obj.RxBuffer{symbolNumFrame+1, packetInfo.RNTI} = packetInfo.Packet;
            end
        end
    end
    
    methods (Access = private)
        function puschRx(obj, puschInfo, currentTime)
            %puschRx Receive the MAC PDU corresponding to PUSCH and send it to MAC
            
            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number w.r.t start of 10 ms frame
            
            % Calculate Rx start symbol number w.r.t start of the 10 ms frame
            if symbolNumFrame == 0 % Packet was received in the previous frame
                rxStartSymbol = obj.CarrierInformation.SymbolsPerFrame -  puschInfo.PUSCHConfig.SymbolAllocation(2);
            else % Packet was received in the current frame
                rxStartSymbol = symbolNumFrame -  puschInfo.PUSCHConfig.SymbolAllocation(2);
            end
            macPDU = obj.RxBuffer{rxStartSymbol+1, puschInfo.PUSCHConfig.RNTI}; % Read the stored MAC PDU corresponding to PUSCH
            obj.RxBuffer{rxStartSymbol+1, puschInfo.PUSCHConfig.RNTI} = {}; % Clear the buffer
            crcFlag = crcResult(obj);
            
            % Increment the number of erroneous received for UE
            obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 1) = obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 1) + crcFlag;
            % Increment the number of received packets for UE
            obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 2) = obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 2) + 1;
            
            % Rx callback to MAC
            macPDUInfo = hNRRxIndicationInfo;
            macPDUInfo.RNTI = puschInfo.PUSCHConfig.RNTI;
            macPDUInfo.TBS = puschInfo.TBS;
            macPDUInfo.HARQID = puschInfo.HARQID;
            obj.RxIndicationFcn(macPDU, crcFlag, macPDUInfo);
            
            if ~isempty(obj.PacketLogger) % Packet capture enabled
                logPackets(obj, puschInfo, macPDU, 1, currentTime); % Log UL packets
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

        function nextInvokeTime = getNextInvokeTime(obj, ~)
            %getNextInvokeTime Return the next invoke time for PHY

            % Find the next PHY Rx invoke time
            puschRxNextInvokeTime = min(obj.DataRxTime);

            nextInvokeTime = puschRxNextInvokeTime;
        end
    end

    methods (Hidden = true)
        function dlTTIRequest(obj, pduType, dlControlPDU)
            dlControlRequest(obj, pduType, dlControlPDU);
        end
    end
end