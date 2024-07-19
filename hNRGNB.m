classdef hNRGNB < hNRNode
%hNRGNB Create a gNB node object that manages the RLC, MAC and Phy layers
%   The class creates a gNB node containing the RLC, MAC and Phy layers of
%   NR protocol stack. Additionally, it models the interaction between
%   those layers through callbacks.

% Copyright 2019-2022 The MathWorks, Inc.

    methods (Access = public)
        function obj = hNRGNB(param)
            %hNRGNB Create a gNB node
            %
            %   OBJ = hNRGNB(PARAM) creates a gNB node containing RLC and MAC.
            %   PARAM is a structure with following fields:
            %       NumUEs                   - Number of UEs in the cell
            %       SCS                      - Subcarrier spacing used
            %       NumHARQ                  - Number of HARQ processes
            %       MaxLogicalChannels       - Maximum number of logical channels that can be configured
            %       Position                 - Position of gNB in (x,y,z) coordinates
            
            % Validate the number of UEs
            validateattributes(param.NumUEs, {'numeric'}, {'nonempty', ...
                'integer', 'scalar', '>', 0, '<=', 65519}, 'param.NumUEs', 'NumUEs');
            % Validate gNB position
            validateattributes(param.Position, {'numeric'}, {'numel', 3, ...
                'nonempty', 'finite', 'nonnan'}, 'param.Position', 'Position');

            % Create gNB MAC instance
            obj.MACEntity = hNRGNBMAC(param);
            % Initialize RLC entities cell array
            obj.RLCEntities = cell(param.NumUEs, obj.MaxLogicalChannels);
            % Initialize application layer
            obj.AppLayer = hApplication('ID', obj.ID, 'MaxApplications', ...
                obj.MaxApplications * param.NumUEs);
            % Register the callback to implement the interaction between
            % MAC and RLC. 'sendRLCPDUs' is the callback to RLC by MAC to
            % get RLC PDUs for the downlink transmissions. 'receiveRLCPDUs'
            % is the callback to RLC by MAC to receive RLC PDUs, for the
            % received uplink packets
            registerRLCInterfaceFcn(obj.MACEntity, @obj.sendRLCPDUs, @obj.receiveRLCPDUs);

            obj.Position = param.Position;
        end

        function configurePhy(obj, configParam)
            %configurePhy Configure the physical layer
            %
            %   configurePhy(OBJ, CONFIGPARAM) sets the physical layer
            %   configuration.
            
            % Validate number of RBs
            validateattributes(configParam.NumRBs, {'numeric'}, {'integer', 'scalar', '>=', 1, '<=', 275}, 'configParam.NumRBs', 'NumRBs');

            if isfield(configParam , 'NCellID')
                % Validate cell ID
                validateattributes(configParam.NCellID, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1007}, 'configParam.NCellID', 'NCellID');
                cellConfig.NCellID = configParam.NCellID;
            else
                cellConfig.NCellID = 1;
            end
            if isfield(configParam , 'DuplexMode')
                % Validate duplex mode
                validateattributes(configParam.DuplexMode, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<', 2}, 'configParam.DuplexMode', 'DuplexMode');
                cellConfig.DuplexMode = configParam.DuplexMode;
            else
                cellConfig.DuplexMode = 0;
            end
            % Set cell configuration on Phy layer instance
            setCellConfig(obj.PhyEntity, cellConfig);

            % Validate the subcarrier spacing
            if ~ismember(configParam.SCS, [15 30 60 120])
                error('nr5g:hNRGNB:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120).', configParam.SCS);
            end

            carrierInformation.SubcarrierSpacing = configParam.SCS;
            carrierInformation.NRBsDL = configParam.NumRBs;
            carrierInformation.NRBsUL = configParam.NumRBs;
            % Validate the uplink and downlink carrier frequencies
            if isfield(configParam, 'ULCarrierFreq')
                validateattributes(configParam.ULCarrierFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.ULCarrierFreq', 'ULCarrierFreq');
                carrierInformation.ULFreq = configParam.ULCarrierFreq;
            end
            if isfield(configParam, 'DLCarrierFreq')
                validateattributes(configParam.DLCarrierFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.DLCarrierFreq', 'DLCarrierFreq');
                carrierInformation.DLFreq = configParam.DLCarrierFreq;
            end
            % Validate uplink and downlink bandwidth
            if isfield(configParam, 'ULBandwidth')
                validateattributes(configParam.ULBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.ULBandwidth', 'ULBandwidth');
                carrierInformation.ULBandwidth = configParam.ULBandwidth;
            end
            if isfield(configParam, 'DLBandwidth')
                validateattributes(configParam.DLBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.DLBandwidth', 'DLBandwidth');
                carrierInformation.DLBandwidth = configParam.DLBandwidth;
            end
            if (cellConfig.DuplexMode == 0) && ((configParam.DLCarrierFreq - configParam.ULCarrierFreq) < (configParam.DLBandwidth+configParam.ULBandwidth)/2)
                error('nr5g:hNRGNB:InsufficientDuplexSpacing', 'DL carrier frequency must be higher than UL carrier frequency by %d MHz for FDD mode', 1e-6*(configParam.DLBandwidth+configParam.ULBandwidth)/2)
            elseif cellConfig.DuplexMode && (configParam.DLCarrierFreq ~= configParam.ULCarrierFreq)
                error('nr5g:hNRGNB:InvalidCarrierFrequency', 'DL and UL carrier frequencies must have the same value for TDD mode')
            end
            % Set carrier configuration on Phy layer instance
            setCarrierInformation(obj.PhyEntity, carrierInformation);
        end

        function setPhyInterface(obj)
            %setPhyInterface Set the interface to Phy

            phyEntity = obj.PhyEntity;
            macEntity = obj.MACEntity;

            % Register Phy interface functions at MAC for:
            % (1) Sending packets to Phy
            % (2) Sending Rx request to Phy
            % (3) Sending DL control request to Phy
            % (4) Sending UL control request to Phy
            registerPhyInterfaceFcn(obj.MACEntity, @phyEntity.txDataRequest, ...
                @phyEntity.rxDataRequest, @phyEntity.dlControlRequest, @phyEntity.ulControlRequest);

            % Register MAC callback function at Phy for:
            % (1) Sending the packets to MAC
            % (2) Sending the measured UL channel quality to MAC
            registerMACInterfaceFcn(obj.PhyEntity, @macEntity.rxIndication, @macEntity.srsIndication);
            
            % Register node object at Phy
            registerNodeWithPhy(obj.PhyEntity, obj);

            % Register node callback function at MAC and Phy for:
            % (1) Sending the out-of-band packets from MAC
            % (2) Sending the in-band packets from Phy
            registerOutofBandTxFcn(macEntity, @obj.addToTxBuffer);
            registerInBandTxFcn(phyEntity, @obj.addToTxBuffer);
        end

        function addScheduler(obj, scheduler)
            %addScheduler Add scheduler object to MAC
            %   addScheduler(OBJ, SCHEDULER) adds scheduler to the MAC
            %
            %   SCHEDULER Scheduler object
            addScheduler(obj.MACEntity, scheduler);
        end
    end
end