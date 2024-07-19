classdef (Abstract) hNRPhyInterface < handle
    %hNRPhyInterface Define NR physical layer interface class
    %   The class acts as a base class for all the physical layer types. It
    %   defines the interface to physical layer. It declares the methods to
    %   be used by higher layers to interact with the physical layer. It
    %   also allows higher layers to install callbacks on physical layer
    %   which are used to send information to higher layers
    %
    %   hNRPhyInterface methods:
    %       setCellConfig          - Set the cell configuration
    %       setCarrierInformation  - Set the carrier configuration
    
    %   Copyright 2020-2022 The MathWorks, Inc.
    
    properties
        %CellConfig Cell configuration
        CellConfig
        
        %CarrierInformation Carrier information
        CarrierInformation

        %LastRunTime Time (in nanoseconds) at which the Phy layer was invoked last time
        LastRunTime = 0;
    end

    properties (Access = protected)
        %DataRxContext Rx context for the Phy
        % Cell array of size 'N' where N is the number of symbols in a 10
        % ms frame. The cell elements are populated with structures of type
        % hNRPDSCHInfo (for UE) or hNRPUSCHInfo (for gNB). The information
        % in the structure is used by the receiver (UE or gNB) for Rx
        % reception and processing. A node reads the complete packet at the
        % symbol in which reception ends. So, an element at index 'i'
        % contains the information for reception which ends at symbol index
        % 'i' w.r.t the start of the frame. There can be array of
        % structures at index 'i', if multiple receptions were scheduled to
        % end at symbol index 'i'. Cell element at 'i' is empty, if no
        % reception was scheduled to end at symbol index 'i'
        DataRxContext

        %DataRxTime Array of data/control information reception timestamps for Phy
        % Array of size 'N' where N is the number of symbols in a 10 ms
        % frame. The array elements are populated with absolute reception
        % times (in nanoseconds). The information will be used in
        % identifying the next invocation time for Phy Rx. In this array,
        % an element at index 'i' contains the absolute invocation time for
        % reception which ends at symbol index 'i' w.r.t the start of the
        % frame. Array element at 'i' is infinite, if no reception was
        % scheduled to end at symbol index 'i'
        DataRxTime

        %DataTxTime Array of data/control information transmission timestamps for Phy
        % Array of size 'N' where N is the number of symbols in a 10 ms
        % frame. The array elements are populated with absolute
        % transmission times (in nanoseconds). The information will be used
        % in identifying the next invocation time for Phy Tx. In this
        % array, an element at index 'i' contains the absolute invocation
        % time for transmission which starts at symbol index 'i' w.r.t the
        % start of the frame. Array element at 'i' is infinite, if no
        % transmission was scheduled to start at symbol index 'i'
        DataTxTime

        %CurrSlot Current running slot number in the 10 ms frame
        CurrSlot = 0;
        
        %CurrSymbol Current running symbol number of the current slot
        CurrSymbol = 0;
        
        %AFN Absolute frame number
        AFN = 0;
        
        %RxIndicationFcn Function handle to send data to MAC
        RxIndicationFcn
        
        %Node Holds a reference to the node object
        % It is configured as an object of type hNRUE for hNRUEPhy and
        % as an object of type hNRGNB for hNRGNBPhy
        Node

        %SendPacketFcn Function handle to transmit the packet
        SendPacketFcn
    end
    
    properties (Constant)
        %CSIRSPDUType CSI-RS PDU type
        CSIRSPDUType = 0;
        
        %SRSPDUType SRS PDU type
        SRSPDUType = 1;

        %FrameDurationInNS Frame duration in nanoseconds
        FrameDurationInNS = 10e6;
    end
    
    methods(Access = public)
        function setCellConfig(obj, cellConfig)
            %setCellConfig Set the cell configuration
            %  setCellConfig(OBJ, CELLCONFIG) sets the cell configuration,
            %  CELLCONFIG.
            %  CELLCONFIG is a structure including the following fields:
            %      NCellID     - Physical cell ID. Values: 0 to 1007 (TS 38.211, sec 7.4.2.1)
            %      DuplexMode  - Duplexing mode. FDD (value 0) or TDD (value 1)
            
            % Validate NCellID
            if isfield(cellConfig, 'NCellID')
                validateattributes(cellConfig.NCellID, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1007}, 'cellConfig.NCellID', 'NCellID');
            end
            
            % Validate duplex mode
            if isfield(cellConfig, 'DuplexMode')
                validateattributes(cellConfig.DuplexMode, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1}, 'cellConfig.DuplexMode', 'DuplexMode');
            end
            
            obj.CellConfig = cellConfig;
        end
        
        function setCarrierInformation(obj, carrierInformation)
            %setCarrierInformation Set the carrier configuration
            %  setCarrierInformation(OBJ, CARRIERINFORMATION) sets the carrier
            %  configuration, CARRIERINFORMATION.
            %  CARRIERINFORMATION is a structure including the following 
            %  fields:
            %      SubcarrierSpacing  - Sub carrier spacing used. Assuming 
            %                           single bandwidth part in the whole
            %                           carrier
            %      NRBsDL             - Downlink bandwidth in terms of 
            %                           number of resource blocks
            %      NRBsUL             - Uplink bandwidth in terms of number
            %                           of resource blocks
            %      DLBandwidth        - Downlink bandwidth in Hz
            %      ULBandwidth        - Uplink bandwidth in Hz
            %      DLFreq             - Downlink carrier frequency in Hz
            %      ULFreq             - Uplink carrier frequency in Hz
            
            % Validate the subcarrier spacing
            if ~ismember(carrierInformation.SubcarrierSpacing, [15 30 60 120])
                error('nr5g:hNRPhyInterface:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120).', carrierInformation.SubcarrierSpacing);
            end
            
            % Validate the number of RBs in the uplink and downlink
            % direction
            if isfield(carrierInformation, 'NRBsUL')
                validateattributes(carrierInformation.NRBsUL, {'numeric'}, {'real', 'integer', 'scalar', '>=', 1, '<=', 275}, 'carrierInformation.NRBsUL', 'NRBsUL');
            end
            if isfield(carrierInformation, 'NRBsDL')
                validateattributes(carrierInformation.NRBsDL, {'numeric'}, {'real', 'integer', 'scalar', '>=', 1, '<=', 275}, 'carrierInformation.NRBsDL', 'NRBsDL');
            end
            
            % Validate uplink and downlink bandwidth
            if isfield(carrierInformation, 'ULBandwidth')
                validateattributes(carrierInformation.ULBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'carrierInformation.ULBandwidth', 'ULBandwidth');
            end
            if isfield(carrierInformation, 'DLBandwidth')
                validateattributes(carrierInformation.DLBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'carrierInformation.DLBandwidth', 'DLBandwidth');
            end
            
            % Validate uplink and downlink carrier frequencies
            if isfield(carrierInformation, 'ULFreq')
                validateattributes(carrierInformation.ULFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>', 0}, 'carrierInformation.ULFreq', 'ULFreq');
            end
            if isfield(carrierInformation, 'DLFreq')
                validateattributes(carrierInformation.DLFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>', 0}, 'carrierInformation.DLFreq', 'DLFreq');              
            end

            slotDuration = 1/(carrierInformation.SubcarrierSpacing/15); % In ms
            carrierInformation.SlotDuration = slotDuration * 1e6; % In nanoseconds
            carrierInformation.SlotsPerSubframe = 1/slotDuration; % Number of slots per 1 ms subframe
            slotsPerFrame = carrierInformation.SlotsPerSubframe*10;
            carrierInformation.SlotsPerFrame = slotsPerFrame; % Number of slots per frame
            carrierInformation.SymbolsPerFrame = slotsPerFrame*14;
            carrierInformation.SymbolTimings = round(((1:14)*slotDuration)/14, 4) * 1e6; % Symbol end times in nanoseconds
            symbolStartTimes = round(((0:13)*slotDuration)/14, 4) * 1e6; % In nanoseconds
            carrierInformation.SymbolDurations = carrierInformation.SymbolTimings - symbolStartTimes;
            obj.CarrierInformation = carrierInformation;
            
            % Initialize data Rx context
            obj.DataRxContext = cell(obj.CarrierInformation.SymbolsPerFrame, 1);
            obj.DataRxTime = Inf(obj.CarrierInformation.SymbolsPerFrame, 1);
            obj.DataTxTime = Inf(obj.CarrierInformation.SymbolsPerFrame, 1);
        end

        function registerNodeWithPhy(obj, node)
            %registerNodeWithPhy Register the node object at Phy layer
            %   registerNodeWithPhy(OBJ, NODE) Sets the reference to node
            %   object at Phy layer
            %
            %   NODE is the reference to the node object passed to Phy
            %   layer
            
            obj.Node = node;
        end

        function registerInBandTxFcn(obj, sendPacketFcn)
            %registerInBandTxFcn Register function handle for transmission
            %
            %   SENDPACKETFCN Function handle provided by packet
            %   distribution object for packet transmission

            obj.SendPacketFcn = sendPacketFcn;
        end
    end
    
    methods(Abstract)
        %txDataRequest Data Tx request from MAC to Phy
        %  txDataRequest(OBJ, TXINFO, MACPDU) is the request from MAC to Phy
        %  to transmit PDSCH (for gNB) or PUSCH (for UE). MAC calls it at the
        %  start of Tx time.
        %
        %  TXINFO is the information sent by MAC which is required for Phy
        %  processing and transmission.
        %
        %  MACPDU is the MAC transport block.
        txDataRequest(obj, txInfo, macPDU)
        
        %rxDataRequest Data Rx request from MAC to Phy
        %  rxDataRequest(OBJ, RXINFO) is the request from MAC to Phy
        %  to receive PUSCH (for gNB) or PDSCH (for UE).The Phy expects to
        %  receive it at the start of reception time
        %
        %  RXINFO is the information sent by MAC which is required by Phy to
        %  receive the packet.
        rxDataRequest(obj, rxInfo)
        
        %dlControlRequest Downlink control request from MAC to Phy
        %  dlControlRequest(OBJ, PDUTYPES, DLCONTROLPDUS) is an indication
        %  from MAC for non-data downlink transmissions/receptions. For
        %  gNB, it is sent by gNB MAC for DL transmissions. For UE, it is
        %  sent by UE MAC for DL receptions. MAC sends it at the start of a
        %  DL slot for all the scheduled DL transmission/receptions in the
        %  slot.
        %
        %  PDUTYPES is an array of DL packet types.
        %
        %  DLCONTROLPDUS is an array of DL control PDUs corresponding to PDUTYPES.
        %
        %  This interface is used for all other DL transmission/reception except for PDSCH transmission/reception.
        dlControlRequest(obj, pduTypes, dlControlPDUs)
        
        %ulControlRequest Uplink control request from MAC to Phy
        %  ulControlRequest(OBJ, PDUTYPES, ULCONTTROLPDUS) is an indication
        %  from MAC for non-data uplink transmissions/receptions. For gNB,
        %  it is sent by gNB MAC for UL receptions. For UE, it is sent by
        %  UE MAC for UL transmissions. MAC sends it at the start of a UL
        %  slot for all the scheduled UL transmission/receptions in the
        %  slot.
        %
        %  PDUTYPES is an array of UL packet types.
        %
        %  ULCONTROLPDUS is an array of UL control PDUs corresponding to PDUTYPES.
        %
        %  This interface is used for all other UL transmission/reception except for PUSCH transmission/reception.
        ulControlRequest(obj, pduTypes, ulControlPDUs)
        
        %registerMACInterfaceFcn Register MAC interface functions at Phy for sending information to MAC
        %  registerMACInterfaceFcn(OBJ, SENDMACPDUFCN, VARARGIN) registers MAC
        %  interface functions at Phy for sending information to MAC. MAC
        %  needs to provide a callback SENDMACPDUFCN to Phy, which Phy would
        %  use to send PDUs up the stack to MAC. Additional callbacks can also
        %  be installed on Phy, as conveyed by variable input arguments, VARARGIN.
        registerMACInterfaceFcn(obj, sendMACPDUFcn, varargin)
    end
end