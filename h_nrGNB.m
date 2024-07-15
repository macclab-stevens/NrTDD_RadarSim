classdef h_nrGNB < wirelessnetwork.internal.nrNode
    %nrGNB 5G NR base station node (gNodeB or gNB)
    %   GNB = nrGNB creates a default 5G New Radio (NR) gNB.
    %
    %   GNB = nrGNB(Name=Value) creates one or more similar gNBs with the
    %   specified property Name set to the specified Value. You can specify
    %   additional name-value arguments in any order as (Name1=Value1, ...,
    %   NameN=ValueN). The number of rows in 'Position' argument defines the
    %   number of gNBs created. 'Position' must be an N-by-3 matrix where
    %   N(>=1) is the number of gNBs, and each row must contain three numeric
    %   values representing the [X, Y, Z] position of a gNB in meters. The
    %   output, GNB is an array of gNB objects containing N gNBs. You can also
    %   supply multiple names for 'Name' argument corresponding to number of
    %   gNBs created. Multiple names must be supplied either as an array of
    %   strings or cell array of character vectors. If name is not set then a
    %   default name as 'NodeX' is given to node, where 'X' is ID of the node.
    %   Assuming 'N' nodes are created and 'M' names are supplied, if (M>N)
    %   then trailing (M-N) names are ignored, and if (N>M) then trailing (N-M)
    %   nodes are set to default names. You can set the "Position" and "Name"
    %   properties corresponding to the multiple gNBs simultaneously when you
    %   specify them as N-V arguments in the constructor. After the node
    %   creation, you can set the "Position" and "Name" property for only one
    %   gNB object at a time.
    %
    %   nrGNB properties (configurable through N-V pair as well as public settable):
    %
    %   Name                 - Node name
    %   Position             - Node position
    %
    %   nrGNB properties (configurable through N-V pair only):
    %
    %   DuplexMode           - Duplexing mode as FDD or TDD
    %   CarrierFrequency     - Carrier frequency at which gNB is operating
    %   ChannelBandwidth     - Bandwidth of the carrier gNB is serving
    %   SubcarrierSpacing    - Subcarrier spacing used across the cell
    %   NumResourceBlocks    - Number of resource blocks in channel bandwidth
    %   NumTransmitAntennas  - Number of transmit antennas
    %   NumReceiveAntennas   - Number of receive antennas
    %   TransmitPower        - Transmit power in dBm
    %   PHYAbstractionMethod - Physical layer (PHY) abstraction method
    %   DLULConfigTDD        - Downlink (DL) and uplink (UL) TDD configuration
    %   NoiseFigure          - Noise figure in dB
    %   ReceiveGain          - Receiver antenna gain in dB
    %   NumHARQ              - Number of hybrid automatic repeat request (HARQ)
    %                          processes for each user equipment (UE) which
    %                          connects to the gNB
    %
    %   nrGNB properties (read-only):
    %
    %   ID                   - Node identifier
    %   ConnectedUEs         - Radio network temporary identifier (RNTI) of the
    %                          connected UEs
    %
    %   Constant properties:
    %
    %   MCSTable             - MCS table used for DL and UL as per 3GPP TS
    %                          38.214 - Table 5.1.3.1-2
    %
    %   nrGNB methods:
    %
    %   connectUE               - Connect UE(s) to the gNB
    %   addTrafficSource        - Add data traffic source to the gNB
    %   statistics              - Get statistics of the gNB
    %   configureScheduler      - Configure scheduler at the gNB
    %   configureULPowerControl - Configure uplink power control at gNB
    %
    %   The scheduler at the gNB assigns the resources based on the configured
    %   scheduling strategy. You can configure scheduler strategies using 
    %   <a href="matlab:help('nrGNB.configureScheduler)">configureScheduler</a> function call. For DL channel measurements, 
    %   the gNB transmits full bandwidth channel state information reference
    %   signal (CSI-RS) which all the UEs in the cell use. For frequency
    %   division duplex (FDD) mode, the periodicity for CSI-RS transmission is
    %   10 slots. For time division duplex (TDD) mode, the periodicity is 'M'
    %   slots. 'M' is the smallest integer which is greater than or equal to 10
    %   and a multiple of the length of the DL-UL pattern (in slots). You can
    %   set different CSI reporting periodicity for the UEs using
    %   'CSIReportPeriodicity' parameter of <a href="matlab:help('nrGNB.connectUE')">connectUE</a> method of this class. 
    %   For UL channel measurements, gNB reserves one symbol for the sounding
    %   reference signal (SRS) periodically, across the entire bandwidth. For
    %   FDD, one SRS symbol is reserved every 5 slots. For TDD, one SRS symbol
    %   is reserved every 'N' slots. 'N' is the smallest integer which is
    %   greater than or equal to 5 and a multiple of the length of the DL-UL
    %   pattern (in slots). The gNB configures the UEs to share the reservation
    %   of SRS bandwidth by differing the comb offset, cyclic shift, or
    %   transmission time. Comb size and maximum cyclic shift are both assumed
    %   as 4. In this case, gNB can configure up to 16 connected UEs to
    %   transmit SRS with periodicity as 'N' slots. If more than 16 UEs
    %   connect, the scheduler increases the SRS transmission periodicity for
    %   each UE to the next higher value (a multiple of 'N') to accommodate
    %   more UEs.
    %
    %   % Example 1:
    %   %  Create two gNBs with name as "gNB1" and "gNB2" positioned at
    %   %  [100 100 0] and [5000 100 0], respectively.
    %   gNBs = nrGNB(Name=["gNB1" "gNB2"], Position=[100 100 0; 5000 100 0])
    %
    %   % Example 2:
    %   %  Create a gNB serving a 20 MHz TDD carrier (or cell). Specify SCS as
    %   %  30e3 Hz with following DL-UL configuration:
    %   %  Periodicity of DL-UL pattern = 2 milliseconds
    %   %  Number of full DL slots = 2
    %   %  Number of DL symbols = 12
    %   %  Number of UL symbols = 0
    %   %  Number of full UL slots = 1
    %   tddConfig = struct('DLULPeriodicity', 2, ...
    %               'NumDLSlots', 2, 'NumDLSymbols', 12, 'NumULSymbols', 0, ...
    %               'NumULSlots', 1)
    %   gNB = nrGNB(ChannelBandwidth=20e6, DuplexMode="TDD", ...
    %   SubcarrierSpacing=30e3, NumResourceBlocks=51, DLULConfigTDD=tddConfig)
    %
    %   % Example 3:
    %   %  Create a gNB and configure its scheduler with these parameters:
    %   %  Resource allocation type = 0
    %   %  Maximum number of scheduled users per TTI = 4
    %   %  Fixed MCS index for DL resource allocation = 10
    %   %  Fixed MCS index for UL resource allocation = 10
    %   gNB = nrGNB();
    %   configureScheduler(gNB, ResourceAllocationType=0, ...
    %       MaxNumUsersPerTTI=4, FixedMCSIndexDL=10, FixedMCSIndexUL=10);
    %
    %   See also nrUE.

    %   Copyright 2022-2023 The MathWorks, Inc.

    properties (SetAccess = private)
        %NoiseFigure Noise figure in dB
        %   Specify the noise figure in dB. The default value is 6.
        NoiseFigure(1,1) {mustBeNumeric, mustBeFinite, mustBeNonnegative} = 6;

        %ReceiveGain Receiver gain in dB
        %   Specify the receiver gain in dB. The default value is 6.
        ReceiveGain(1,1) {mustBeNumeric, mustBeFinite, mustBeNonnegative} = 6;

        %TransmitPower Transmit power of gNB in dBm
        %   Specify the transmit power of gNB. Units are in dBm.
        %   The default value is 34.
        TransmitPower (1,1) {mustBeNumeric, mustBeFinite, mustBeLessThanOrEqual(TransmitPower, 60)} = 34

        %NumTransmitAntennas Number of transmit antennas on gNB
        %   Specify the number of transmit antennas on gNB. The allowed values are
        %   1, 2, 4, 8, 16, 32. The default value is 1.
        NumTransmitAntennas (1, 1) {mustBeNumeric, mustBeMember(NumTransmitAntennas, ...
            [1 2 4 8 16 32])} = 1;

        %NumReceiveAntennas Number of receive antennas on gNB
        %   Specify the number of receive antennas on gNB. The allowed values are
        %   1, 2, 4, 8, 16, 32. The default value is 1.
        NumReceiveAntennas (1, 1) {mustBeNumeric, mustBeMember(NumReceiveAntennas, ...
            [1 2 4 8 16 32])} = 1;

        %PHYAbstractionMethod PHY abstraction method
        %   Specify the PHY abstraction method as "linkToSystemMapping" or "none".
        %   The value "linkToSystemMapping" represents link-to-system-mapping based
        %   abstract PHY. The value "none" represents full PHY processing. The default
        %   value is "linkToSystemMapping".
        PHYAbstractionMethod = "linkToSystemMapping";

        %DuplexMode Duplex mode as FDD or TDD
        %   Specify the duplex mode either as frequency division duplexing
        %   (FDD) or time division duplexing (TDD). The allowed values
        %   are "FDD" or "TDD". The default value is "FDD".
        DuplexMode {mustBeNonempty, mustBeTextScalar} = "FDD";

        %CarrierFrequency Frequency of the carrier served by gNB in Hz
        %   Specify the carrier frequency in Hz. The default value is 2.6e9 Hz.
        CarrierFrequency (1,1) {mustBeNumeric, mustBeFinite, mustBeGreaterThanOrEqual(CarrierFrequency, 600e6)} = 2.6e9;

        %ChannelBandwidth Bandwidth of the carrier served by gNB in Hz
        %   Specify the carrier bandwidth in Hz. In FDD mode, each of the
        %   DL and UL operations happen in separate bands of this size. In
        %   TDD mode, both DL and UL share single band of this size. The
        %   default value is 5e6 Hz.
        ChannelBandwidth (1,1) {mustBeNumeric, mustBeFinite, mustBePositive, mustBeMember(ChannelBandwidth, ...
            [5e6 10e6 15e6 20e6 25e6 30e6 35e6 40e6 45e6 50e6 60e6 70e6 80e6 90e6 100e6 200e6 400e6])} = 5e6;

        %SubcarrierSpacing Subcarrier spacing (SCS) used across the cell
        %   Specify the subcarrier spacing for the cell in Hz. All the UE(s)
        %   connecting to the gNB operates in this SCS. The allowed values are
        %   15e3, 30e3, 60e3 and 120e3. The default value is 15e3.
        SubcarrierSpacing (1, 1) {mustBeNumeric, mustBeMember(SubcarrierSpacing, [15e3 30e3 60e3 120e3])} = 15e3;

        %NumResourceBlocks Number of resource blocks in carrier bandwidth
        %   Specify the number of resource blocks in carrier bandwidth. In FDD
        %   mode, each of the DL and UL bandwidth contains these many resource
        %   blocks. In TDD mode, both DL and UL bandwidth share these resource
        %   blocks. If you do not set this value then the gNB derives it
        %   automatically from channel bandwidth and subcarrier spacing. The
        %   default value is 25 which corresponds to the default 5e6 Hz channel
        %   bandwidth and 15e3 Hz SCS. The minimum value is 4 which is the minimum
        %   required transmission bandwidth for SRS as per 3GPP TS 38.211 Table
        %   6.4.1.4.3-1.
        NumResourceBlocks (1,1) {mustBeNumeric, mustBeInteger, mustBeFinite, mustBeGreaterThanOrEqual(NumResourceBlocks, 4)} = 25;

        %DLULConfigTDD Downlink and uplink time configuration (relevant only for TDD mode)
        %   Specify the DL and UL time configuration for TDD mode. Set this
        %   property only if you have set the 'DuplexMode' as "TDD", otherwise
        %   the set value is ignored. This property corresponds to
        %   tdd-UL-DL-ConfigurationCommon parameter as described in Section 11.1 of
        %   3GPP TS 38.213. Specify it as a structure with following fields:
        %   DLULPeriodicity    - DL-UL pattern periodicity in milliseconds
        %   NumDLSlots         - Number of full DL slots at the start of DL-UL pattern
        %   NumDLSymbols       - Number of DL symbols after full DL slots
        %   NumULSymbols       - Number of UL symbols before full UL slots
        %   NumULSlots         - Number of full UL slots at the end of DL-UL pattern
        %
        %   The reference subcarrier spacing for DL-UL pattern is assumed
        %   to be same as 'SubcarrierSpacing' property of this class. The
        %   configuration supports one 'S' slot after full DL slots and
        %   before full UL slots. The 'S' slot comprises of 'NumDLSymbols'
        %   at the start and 'NumULSymbols' at the end. The symbol count
        %   '14 - (NumDLSymbols + NumULSymbols)' is assumed to be guard
        %   period between DL and UL time. 'NumULSymbols' can be set to 0
        %   or 1. If set to 1 then this UL symbol is utilized for sounding
        %   reference signal (SRS). The default values for the structure
        %   fields are: DLULPeriodicity = 5, NumDLSlots = 2, NumDLSymbols =
        %   12, NumULSymbols = 1, NumULSlots = 2. The default value
        %   corresponds to 15e3 Hz SCS. If you specify SCS as 30e3 Hz, 60e3
        %   Hz, or 120e3 Hz then the default value of DLULPeriodicity field
        %   becomes 2.5 milliseconds, 1.25 milliseconds, 0.625
        %   milliseconds, respectively.
        DLULConfigTDD = struct('DLULPeriodicity', 5, 'NumDLSlots', 2, ...
            'NumDLSymbols', 12, 'NumULSymbols', 1, 'NumULSlots', 2);

        %NumHARQ Number of HARQ processes used for each UE in DL and UL direction
        %   Specify the number of HARQ processes used for each UE in DL and
        %   UL direction. The default value is 16.
        NumHARQ(1, 1) {mustBeNumeric, mustBeInteger, mustBeInRange(NumHARQ, 1, 16)} = 16;

        %ULPowerControlParameters Specify the uplink power control configuration parameters
        %   This property is used to configure the uplink power control
        %   This property corresponds to parameter PUSCH-PowerControl described
        %   in 3GPP TS 38.213 section 7.1. It is as a structure containing the following fields
        %   PoPUSCH     - Nominal transmit power of the UE in dBm per resource block
        %   AlphaPUSCH  - Fractional power control multiplier of an UE specified at gNB
        %
        %   The range of PoPUSCH is [-202, 24]. Allowed values of AlphaPUSCH are
        %   0 0.4 0.5 0.6 0.7 0.8 0.9, or 1. The default values for the structure
        %   fields are PoPUSCH = -60 dBm, AlphaPUSCH = 1 which corresponds to
        %   conventional power control scheme which will  maintain a constant
        %   signal to interference and noise ratio (SINR) at the receiver.
        ULPowerControlParameters = struct('PoPUSCH', -60, 'AlphaPUSCH', 1);
    end

    properties(SetAccess = private)
        %ConnectedUEs RNTI of the UEs connected to the gNB, represented as vector of integers
        ConnectedUEs
    end

    properties(SetAccess = private, Hidden)
        %NCellID Physical layer cell identity of the carrier gNB is serving
        NCellID

        %ConnectedUENodes Cell array of UE node objects connected to the gNB
        ConnectedUENodes = {}
    end
    
    properties(Hidden)
        %GuardBand Gap between DL and UL bands in Hz (Only valid for FDD)
        GuardBand = 140e6;

        %SRSReservedResource SRS reservation occurrence period as [symbolNumber slotPeriodicity slotOffset]
        SRSReservedResource

        %SRSConfiguration Array of SRS configurations
        SRSConfiguration

        %SRSOccupancyStatus Binary array containing assignment status of SRSs in SRSConfiguration
        SRSOccupancyStatus

        %CSIRSConfiguration CSI-RS configuration shared by all the UEs in the cell
        CSIRSConfiguration

        %CQITable CQI table (TS 38.214 - Table 5.2.2.1-3) used for channel quality measurements
        CQITable = 'table2';
    end

    properties(SetAccess = protected, Hidden)
        %CSIReportType CSI report type that takes values 1 and 2 to indicate type-I
        %and type-II, respectively
        CSIReportType = 1
    end

    properties(Access = protected)
        %SchedulerDefaultConfig Flag, specified as true or false, indicating the
        %scheduler with a default or custom configuration. A flag value of true
        %indicates that the scheduler has a default configuration, and a flag value
        %of false indicates that the scheduler has a custom configuration.
        SchedulerDefaultConfig = true
    end

    events(Hidden)
        %ScheduledResources Event of resource scheduling
        %   This event is triggered when scheduler runs to schedule
        %   resources. It passes the event notification along with
        %   structure containing these fields to the registered callback:
        %   CurrentTime    - Current simulation time in seconds
        %   TimingInfo     - Timing information as vector of 3 elements of the form
        %                    [SystemFrameNumber SlotNumber SymbolNumber]
        %   NCellID        - Physical cell identity of the carrier gNB is serving
        %   DLGrants       - Structure containing scheduled downlink grants
        %   ULGrants       - Structure containing scheduled uplink grants
        ScheduledResources
    end

    properties(Constant)
        %MCSTable MCS table to be used for DL and UL as per 3GPP TS 38.214 - Table 5.1.3.1-2
        MCSTable = nrGNB.getMCSTable;
    end

    % Constant, hidden properties
    properties (Constant,Hidden)
        DuplexMode_Values  = ["FDD","TDD"];

        SubcarrierSpacing_Values = ["15000","30000","60000","120000"];
    end

    methods
        function obj = nrGNB(varargin)

            % Name-value pair check
            coder.internal.errorIf(mod(nargin, 2) == 1,'MATLAB:system:invalidPVPairs');

            if nargin > 0
                % Validate inputs
                param = nr5g.internal.nrNodeValidation.validateGNBInputs(obj, varargin);
                names = param(1:2:end);
                % Search the presence of 'Position' N-V argument to
                % calculate the number of gNBs user intends to create
                positionIdx = find(strcmp([names{:}], 'Position'), 1, 'last');
                numGNBs = 1;
                if ~isempty(positionIdx)
                    position = param{2*positionIdx}; % Read value of Position N-V argument
                    validateattributes(position, {'numeric'}, {'nonempty', 'ncols', 3, 'finite'}, mfilename, 'Position');
                    if ismatrix(position)
                        numGNBs = size(position, 1);
                    end
                end

                % Search the presence of 'Name' N-V pair argument
                nameIdx = find(strcmp([names{:}], 'Name'), 1, 'last');
                if ~isempty(nameIdx)
                    nodeName = param{2*nameIdx}; % Read value of Position N-V argument
                end

                % Create gNB(s)
                obj(1:numGNBs) = obj;
                for i=2:numGNBs
                    obj(i) = nrGNB;
                end

                % Set the configuration of gNB(s) as per the N-V pairs
                numArgs = numel(param);
                for i=1:2:numArgs-1
                    name = param{i};
                    value = param{i+1};
                    switch (name)
                        case 'Position'
                            % Set position for gNB(s)
                            for j = 1:numGNBs
                                obj(j).Position = position(j, :);
                            end
                        case 'Name'
                            % Set name for gNB(s). If name is not supplied for all gNBs then leave the
                            % trailing gNBs with default names
                            nameCount = min(numel(nodeName), numGNBs);
                            for j=1:nameCount
                                obj(j).Name = nodeName(j);
                            end
                        otherwise
                            % Make all the gNBs identical by setting same value for all the
                            % configurable properties, except position and name
                            [obj.(char(name))] = deal(value);
                    end
                end
            end
            % Set physical cell ID same as node ID
            [obj.NCellID] = deal(obj.ID);

            if strcmp(obj(1).DuplexMode, "FDD") % FDD
                % UL band starts guardBand*0.5 Hz below the carrier frequency and it is
                % channelBandwidth Hz wide. UL carrier frequency is calculated as center of
                % UL band
                [obj.ULCarrierFrequency] = deal(obj(1).CarrierFrequency-(obj(1).GuardBand/2)-(obj(1).ChannelBandwidth/2));
                % DL band starts guardBand*0.5 Hz above the carrier frequency and is
                % channelBandwidth Hz wide. DL carrier frequency is calculated as center of
                % DL band
                [obj.DLCarrierFrequency] = deal(obj(1).CarrierFrequency+(obj(1).GuardBand/2)+(obj(1).ChannelBandwidth/2));
            else % TDD
                [obj.ULCarrierFrequency] = deal(obj(1).CarrierFrequency);
                [obj.DLCarrierFrequency] = deal(obj(1).CarrierFrequency);
            end
            % Create internal layers for each gNB
            macParam = {'NCellID', 'NumHARQ', 'SubcarrierSpacing'};
            phyParam = {'NCellID', 'DuplexMode', 'ChannelBandwidth', 'DLCarrierFrequency', ...
                'ULCarrierFrequency', 'NumResourceBlocks', 'TransmitPower', ... 
                'NumTransmitAntennas', 'NumReceiveAntennas', 'NoiseFigure', ...
                'ReceiveGain', 'Position', 'SubcarrierSpacing', 'CQITable'};
            for idx=1:numel(obj) % For each gNB
                gNB = obj(idx);

                % Set up traffic manager
                gNB.TrafficManager = wirelessnetwork.internal.trafficManager(gNB.ID, ...
                    [], @gNB.processEvents, DataAbstraction=false, ...
                    PacketContext=struct('DestinationNodeID', 0, 'LogicalChannelID', 4, 'RNTI', 0));

                % Set up MAC
                macInfo = struct();
                for j=1:numel(macParam)
                    macInfo.(char(macParam{j})) = gNB.(char(macParam{j}));
                end
                % Convert the SCS value from Hz to kHz
                subcarrierSpacingInKHZ = gNB.SubcarrierSpacing/1e3;
                macInfo.SubcarrierSpacing = subcarrierSpacingInKHZ;
                gNB.MACEntity = nr5g.internal.nrGNBMAC(macInfo, @gNB.processEvents);

                % Create SRS configurations and mark all as
                % free/unassigned. Scheduler is conveyed SRS resource
                % occurrence periodicity so that it can reserve SRS
                % symbols to exclude them for data scheduling
                [gNB.SRSReservedResource, gNB.SRSConfiguration] = createSRSConfiguration(gNB);
                gNB.SRSOccupancyStatus = zeros(length(gNB.SRSConfiguration), 1);

                % Create CSI-RS configuration to be shared by all the UEs
                % in the cell
                gNB.CSIRSConfiguration = gNB.createCSIRSConfiguration();
                % Set up default scheduler
                configureScheduler(gNB);
                gNB.SchedulerDefaultConfig = true;

                % Set up PHY
                phyInfo = struct();
                for j=1:numel(phyParam)
                    phyInfo.(char(phyParam{j})) = gNB.(char(phyParam{j}));
                end
                phyInfo.SubcarrierSpacing = subcarrierSpacingInKHZ;
                if strcmp(gNB.PHYAbstractionMethod, "none")
                    gNB.PhyEntity = nr5g.internal.nrGNBFullPHY(phyInfo); % Full PHY
                    gNB.PHYAbstraction = 0;
                else
                    gNB.PhyEntity = nr5g.internal.nrGNBAbstractPHY(phyInfo); % Abstract PHY
                    gNB.PHYAbstraction = 1;
                end

                % Set inter-layer interfaces
                gNB.setLayerInterfaces();
                gNB.ReceiveFrequency = gNB.ULCarrierFrequency;
            end
        end

        function connectUE(obj, UE, varargin)
            %connectUE Connect one or more UEs to the gNB
            %
            %   connectUE(OBJ, UE, Name=Value) connects one or more UEs to gNB as per
            %   the connection configuration parameters specified in name-value
            %   arguments. UE is an array of objects of type <a
            %   href="matlab:help('nrUE')">nrUE</a> and represents one or more UEs
            %   getting connected to gNB. You can set connection parameter using
            %   name-value arguments in any order as (Name1=Value1,...,NameN=ValueN).
            %   When a name-value argument corresponding to a connection parameter is
            %   not specified, the method uses a default value for it. All the nodes in
            %   object array, UE, connect using same specified value of the connection
            %   parameter. Use these name-value arguments to set connection parameters.
            %
            %   BSRPeriodicity       - UL buffer status reporting periodicity in
            %                          terms of the number of subframes (1 subframe
            %                          is 1 millisecond). The default value is 5.
            %
            %   CSIReportPeriodicity - CSI-RS reporting periodicity in terms of
            %                          the number of slots. UE reports rank indicator
            %                          (RI), precoding matrix indicator (PMI), and CQI
            %                          based on the measurements done on configured
            %                          CSI-RS. Specify this parameter as a value
            %                          greater than or equal to CSI-RS transmission
            %                          periodicity. For TDD, this parameter must also
            %                          be a multiple of length of DL-UL pattern in
            %                          slots. The default value for reporting
            %                          periodicity is same as the CSI-RS transmission
            %                          periodicity.
            %
            %   FullBufferTraffic    - Enable full buffer traffic in DL and/or UL
            %                          direction for the UE. Possible values: "off",
            %                          "on", "DL" and "UL". Value "on" configures full
            %                          buffer traffic for both DL and UL direction.
            %                          Value "DL" configures full buffer traffic only
            %                          for DL direction. Value "UL" configures full
            %                          buffer traffic only for UL direction. Default
            %                          value is "off" which means that full buffer
            %                          traffic is disabled in DL and UL direction. Use
            %                          this configuration parameter as an alternative
            %                          to <a
            %                          href="matlab:help('nrGNB.addTrafficSource')">addTrafficSource</a> for easily setting up traffic
            %                          during connection configuration itself.
            %
            %   RLCBearerConfig      - RLC bearer configuration, specified as 
            %                          an <a
            %                          href="matlab:help('nrRLCBearerConfig')">nrRLCBearerConfig</a> object or an array of 
            %                          <a href="matlab:help('nrRLCBearerConfig')">nrRLCBearerConfig</a> objects. Use this option when
            %                          full buffer is not enabled. If you enable
            %                          the full buffer on the DL or UL direction,
            %                          the object ignores this value. If you do not
            %                          enable the full buffer and you do not specify
            %                          this value, the object uses a default RLC
            %                          bearer configuration.

            % First argument must be scalar object
            validateattributes(obj, {'nrGNB'}, {'scalar'}, mfilename, 'obj');
            validateattributes(UE, {'nrUE'}, {'vector'}, mfilename, 'UE');

            coder.internal.errorIf(~isempty(obj.CurrentTime), 'nr5g:nrNode:NotSupportedOperation', 'ConnectUE');

            % Name-value pair check
            coder.internal.errorIf(mod(numel(varargin), 2) == 1, 'MATLAB:system:invalidPVPairs');
            numUEs = length(UE);
            connectionConfigStruct = struct('RNTI', 0, 'GNBID', obj.ID, 'GNBName', ...
                obj.Name, 'UEID', 0, 'UEName', [], 'NCellID', obj.NCellID, ...
                'SubcarrierSpacing', obj.SubcarrierSpacing, 'SchedulingType', ...
                0, 'NumHARQ', obj.NumHARQ, 'DuplexMode', obj.DuplexMode, ...
                'CSIRSConfiguration', obj.CSIRSConfiguration, 'CSIReportConfiguration', [],  'SRSConfiguration', ...
                [], 'SRSSubbandSize', [], 'NumResourceBlocks', obj.NumResourceBlocks, ...
                'ChannelBandwidth', obj.ChannelBandwidth, 'DLCarrierFrequency', ...
                obj.DLCarrierFrequency, 'ULCarrierFrequency', obj.ULCarrierFrequency, ...
                'BSRPeriodicity', 5, 'CSIReportPeriodicity', [], 'CSIReportPeriodicityRSRP', ...
                1, 'RBGSizeConfiguration', 1, 'DLULConfigTDD', obj.DLULConfigTDD, ...
                'NumTransmitAntennas', 1, 'NumReceiveAntennas', 1,  'InitialMCSIndexDL', 11,...
                'PoPUSCH', obj.ULPowerControlParameters.PoPUSCH, 'AlphaPUSCH', obj.ULPowerControlParameters.AlphaPUSCH,...
                'GNBTransmitPower', [],...
                'InitialMCSIndexUL', 11, 'InitialCQIDL', 0, 'InitialCQIUL', 0, ...
                'FullBufferTraffic', "off", 'RLCBearerConfig', []);

            % Initialize connection configuration array for UEs
            connectionConfigList = repmat(connectionConfigStruct, numUEs, 1);

            % Form array of connection configuration (1 for each UE)
            for idx=1:2:nargin-2
                name = varargin{idx};
                value = nr5g.internal.nrNodeValidation.validateConnectUEInputs(name, varargin{idx+1});
                % Set same value per connection
                [connectionConfigList(:).(char(name))] = deal(value);
            end

            % Information to configure connection information at gNB MAC
            macConnectionParam = {'RNTI', 'UEID', 'UEName', 'CSIRSConfiguration', 'SRSConfiguration'};
            % Information to configure connection information at gNB PHY
            phyConnectionParam = {'RNTI', 'UEID', 'UEName', 'SRSSubbandSize', 'NumHARQ'};
            % Information to configure connection information at gNB scheduler
            schedulerConnectionParam = {'RNTI', 'UEID', 'UEName', 'NumTransmitAntennas', 'NumReceiveAntennas', ...
                'SRSConfiguration', 'CSIRSConfiguration', 'CSIReportConfiguration', 'SRSSubbandSize', ...
                'InitialCQIDL', 'InitialCQIUL'};
            % Information to configure connection information at gNB RLC
            rlcConnectionParam = {'RNTI', 'FullBufferTraffic', 'RLCBearerConfig'};

            % Set connection for each UE
            for i=1:numUEs
                if numUEs == 1
                    coder.internal.errorIf(strcmpi(UE(i).ConnectionState, "Connected") && ismember(UE(i).RNTI, obj.ConnectedUEs), 'nr5g:nrGNB:AlreadyConnectedScalar');
                    coder.internal.errorIf(strcmpi(UE(i).ConnectionState, "Connected") && ~isempty(UE(i).GNBNodeID), 'nr5g:nrGNB:InvalidConnectionScalar', UE(i).GNBNodeID);
                else
                    coder.internal.errorIf(strcmpi(UE(i).ConnectionState, "Connected") && ismember(UE(i).RNTI, obj.ConnectedUEs), 'nr5g:nrGNB:AlreadyConnected', i);
                    coder.internal.errorIf(strcmpi(UE(i).ConnectionState, "Connected") && ~isempty(UE(i).GNBNodeID), 'nr5g:nrGNB:InvalidConnection', i, UE(i).GNBNodeID);
                end

                % Update connection information
                rnti = length(obj.ConnectedUEs)+1;
                connectionConfig = connectionConfigList(i); % UE specific configuration
                freeSRSIndex = find(obj.SRSOccupancyStatus==0, 1); % First free SRS resource index
                if isempty(freeSRSIndex)
                    % No free SRS configuration. Increase the per-UE periodicity
                    % of SRS to accommodate more UEs
                    updateSRSPeriodicity(obj);
                    freeSRSIndex = find(obj.SRSOccupancyStatus==0, 1); % First free SRS resource index
                end

                % Fill connection configuration
                srsConfig = obj.SRSConfiguration(freeSRSIndex);
                srsConfig.NumSRSPorts = UE(i).NumTransmitAntennas;
                srsConfig.NSRSID = obj.NCellID;
                connectionConfig.SRSConfiguration = srsConfig;
                connectionConfig.RNTI = rnti;
                connectionConfig.NCellID = obj.NCellID;
                connectionConfig.UEID = UE(i).ID;
                connectionConfig.UEName = UE(i).Name;
                connectionConfig.NumTransmitAntennas = UE(i).NumTransmitAntennas;
                connectionConfig.NumReceiveAntennas = UE(i).NumReceiveAntennas;
                connectionConfig.CSIRSConfiguration.NID = obj.NCellID;
                connectionConfig.CSIReportType = obj.CSIReportType;

                % Validate connection information
                connectionConfig = nr5g.internal.nrNodeValidation.validateConnectionConfig(connectionConfig);
                connectionConfig.CSIReportConfiguration.CQITable = obj.CQITable;
                connectionConfig.InitialCQIDL = nrGNB.getCQIIndex(connectionConfig.InitialMCSIndexDL);
                connectionConfig.InitialCQIUL = nrGNB.getCQIIndex(connectionConfig.InitialMCSIndexUL);

                % Mark the SRS resource as occupied
                obj.SRSConfiguration(freeSRSIndex) = srsConfig;
                obj.SRSOccupancyStatus(freeSRSIndex) = 1;

                % Update list of connected UEs
                obj.ConnectedUEs(end+1) = rnti;
                obj.ConnectedUENodes{end+1} = UE(i);

                % Add connection context to gNB MAC
                macConnectionInfo = struct();
                for j=1:numel(macConnectionParam)
                    macConnectionInfo.(char(macConnectionParam{j})) = connectionConfig.(char(macConnectionParam{j}));
                end
                obj.MACEntity.addConnection(macConnectionInfo);

                % Add connection context to gNB PHY
                phyConnectionInfo = struct();
                for j=1:numel(phyConnectionParam)
                    phyConnectionInfo.(char(phyConnectionParam{j})) = connectionConfig.(char(phyConnectionParam{j}));
                end
                obj.PhyEntity.addConnection(phyConnectionInfo);
                connectionConfig.GNBTransmitPower = obj.PhyEntity.scaleTransmitPower;

                % Add connection context to gNB scheduler
                schedulerConnectionInfo = struct();
                for j=1:numel(schedulerConnectionParam)
                    schedulerConnectionInfo.(char(schedulerConnectionParam{j})) = connectionConfig.(char(schedulerConnectionParam{j}));
                end
                obj.MACEntity.Scheduler.addConnectionContext(schedulerConnectionInfo);

                % Add connection context to gNB RLC entity
                rlcConnectionInfo = struct();
                for j=1:numel(rlcConnectionParam)
                    rlcConnectionInfo.(char(rlcConnectionParam{j})) = connectionConfig.(char(rlcConnectionParam{j}));
                end
                obj.FullBufferTraffic(rnti) = rlcConnectionInfo.FullBufferTraffic;
                addRLCBearer(obj, rlcConnectionInfo)

                % Set up connection on UE
                UE(i).addConnection(connectionConfig);
            end
        end

        function stats = statistics(obj, varargin)
            %statistics Return the statistics of gNB
            %
            %   STATS = statistics(OBJ) returns the statistics of the gNB, OBJ. 
            %   STATS is a structure with these fields.
            %   ID   - ID of the gNB
            %   Name - Name of the gNB
            %   App  - Application layer statistics
            %   RLC  - RLC layer statistics
            %   MAC  - MAC layer statistics
            %   PHY  - PHY layer statistics
            %
            %   STATS = statistics(OBJ, "all") returns the per-destination
            %   categorization of stats in addition to the output from the previous
            %   syntax. This syntax additionally returns a structure field
            %   'Destinations' for each layer to show per-destination statistics.
            %
            %   App is a structure with these fields.
            %   TransmittedPackets  - Total number of packets transmitted to the RLC layer
            %   TransmittedBytes    - Total number of bytes transmitted to the RLC layer
            %   ReceivedPackets     - Total number of packets received from the RLC layer
            %   ReceivedBytes       - Total number of bytes received from the RLC layer
            %   Destinations        - Array of structures of size '1xN' where 'N' is
            %                         the number of connected UEs. Each structure
            %                         element corresponds to a connected UE and has
            %                         fields: UEID, UEName, RNTI, TransmittedPackets,
            %                         TransmittedBytes.
            %
            %   RLC is a structure with these fields.
            %   TransmittedPackets  - Total number of packets transmitted to the MAC layer
            %   TransmittedBytes    - Total number of bytes transmitted to the MAC layer
            %   ReceivedPackets     - Total number of packets received from the MAC layer
            %   ReceivedBytes       - Total number of bytes received from the MAC layer
            %   DroppedPackets      - Total number of received packets dropped due to
            %                         reassembly failure
            %   DroppedBytes        - Total number of received bytes dropped due to
            %                         reassembly failure
            %   Destinations        - Array of structures of size '1xN' where 'N' is 
            %                         the number of connected UEs. Each structure
            %                         element corresponds to a connected UE and has
            %                         fields: UEID, UEName, RNTI, TransmittedPackets,
            %                         TransmittedBytes, ReceivedPackets, ReceivedBytes,
            %                         DroppedPackets, DroppedBytes.
            %
            %   MAC is a structure with these fields.
            %   TransmittedPackets  - Total number of packets transmitted to the PHY layer.
            %                         It only corresponds to new transmissions assuming
            %                         that MAC does not send the packet again to the
            %                         PHY for retransmissions. Packets are buffered at
            %                         PHY. MAC only sends the requests for
            %                         retransmission to the PHY layer.
            %   TransmittedBytes    - Total number of bytes transmitted to the PHY layer
            %   ReceivedPackets     - Total number of packets received from the PHY layer
            %   ReceivedBytes       - Total number of bytes received from the PHY layer
            %   Retransmissions     - Total number of retransmissions requests sent to the PHY layer
            %   RetransmissionBytes - Total number of MAC bytes which correspond to the retransmissions
            %   Destinations        - Array of structures of size '1xN' where 'N' is 
            %                         the number of connected UEs. Each structure
            %                         element corresponds to a connected UE and has
            %                         fields: UEID, UEName, RNTI, TransmittedPackets,
            %                         TransmittedBytes, ReceivedPackets, ReceivedBytes,
            %                         Retransmissions, RetransmissionBytes.
            %
            %   PHY is a structure with these fields.
            %   TransmittedPackets  - Total number of packets transmitted
            %   ReceivedPackets     - Total number of packets received
            %   DecodeFailures      - Total number of decode failures
            %   Destinations        - Array of structures of size '1xN' where 'N' is 
            %                         the number of connected UEs. Each structure
            %                         element corresponds to a connected UE and has
            %                         fields: UEID, UEName, RNTI, TransmittedPackets,
            %                         ReceivedPackets, DecodeFailures.
            %
            % You can fetch statistics for multiple gNBs at once by calling this
            % function on an array of gNB objects. An element at the index 'i' of STATS
            % contains the statistics of gNB at index 'i' of the gNB array, OBJ.

            narginchk(1, 2);
            if nargin == 1
                stats = arrayfun(@(x) x.statisticsPerGNB, obj);
            else
                validateattributes(varargin{1}, {'char','string'}, {'nonempty', 'scalartext'}, 'statistics','',2);
                coder.internal.errorIf(~any(strcmpi(varargin{1}, ["all" "a" "al"])), ...
                    'nr5g:nrGNB:InvalidStringInputStatistic',varargin{1});
                stats = arrayfun(@(x) x.statisticsPerGNB("all"), obj);
            end
        end

        function configureULPowerControl(obj, nameValuePairs)
            %configureULPowerControl Configure the uplink power control mechanism
            %
            %   configureULPowerControl(OBJ, Name=Value) configures uplink
            %   power control mechanism. This object function sets the power
            %   control configuration parameters using one or more optional
            %   name-value arguments. If you do not specify a name-value argument
            %   corresponding to a configuration parameter, the function assigns a
            %   default value to it. To calculate the UL transmit power, the UE
            %   nodes connected to a gNB node use the same power control parameter
            %   values specified in the name-value arguments. To set the uplink power
            %   control parameters, use these name-value arguments.
            %
            %   PoPUSCH     - Nominal transmit power of a UE per resource block, specified
            %                 as a numeric scalar in the range [-202, 24]. Units are in dBm.
            %                 The default value is -60 dBm. The uplink transmit power
            %                 tends towards the maximum attainable value with an increase
            %                 in PoPUSCH.
            %   Alpha       - Fractional power control multiplier of a UE at the gNB node,
            %                 specified as 0, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, or 1. The default value
            %                 is 1. The uplink transmit power tends towards the maximum attainable
            %                 value with an increase in Alpha.
            % For more information about these name-value arguments, see 3GPP TS 38.213 Section 7.1.
            % To disable the uplink power control, set Alpha to 1 and PoPUSCH to 24 dBm.

            arguments 
                obj (1, 1) {mustBeA(obj, 'nrGNB')}
                nameValuePairs.PoPUSCH (1, 1) {mustBeNumeric, mustBeGreaterThanOrEqual(nameValuePairs.PoPUSCH, -202), ....
                    mustBeLessThanOrEqual(nameValuePairs.PoPUSCH, 24)} = -60
                nameValuePairs.Alpha (1, 1) {mustBeNumeric, mustBeMember(nameValuePairs.Alpha, [0, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1])} = 1
            end

            coder.internal.errorIf(~isempty(obj.CurrentTime), 'nr5g:nrNode:NotSupportedOperation', 'configureULPowerControl');
            coder.internal.errorIf(~isempty(obj.ConnectedUEs), 'nr5g:nrGNB:ConfigULPowerControlAfterConnectUE');

            obj.ULPowerControlParameters.PoPUSCH = nameValuePairs.PoPUSCH;
            obj.ULPowerControlParameters.AlphaPUSCH = nameValuePairs.Alpha;
        end

        function configureScheduler(obj, varargin)
            %configureScheduler Configure scheduler at gNB
            %
            %   configureScheduler(OBJ, Name=Value) configures a scheduler at a gNB
            %   node. The function sets the scheduling parameters using one or more
            %   optional name-value arguments. If you do not specify a name-value
            %   argument corresponding to a configuration parameter, the function
            %   assigns a default value to it. You can configure schedulers for
            %   multiple gNB nodes in a single configureScheduler function call, but
            %   these schedulers must all use same configuration parameter values
            %   specified in the name-value arguments. To set the configuration
            %   parameters, use these name-value arguments.
            %
            %   Scheduler         - Scheduler strategy, specified as "RoundRobin",
            %                       "ProportionalFair", or "BestCQI". The default value
            %                       is "RoundRobin". The RoundRobin scheduler provides
            %                       equal scheduling opportunities to all the UE nodes.
            %                       The BestCQI scheduler, on the other hand, gives
            %                       priority to the UE node with the best channel
            %                       quality indicator (CQI). The BestCQI scheduler
            %                       strategy, therefore, achieves better cell
            %                       throughput. The ProportionalFair scheduler is a
            %                       compromise between the RoundRobin and BestCQI
            %                       schedulers. These three scheduling strategies try
            %                       to schedule 'MaxNumUsersPerTTI' UE nodes in each
            %                       slot.
            %   PFSWindowSize     - Time constant of an exponential moving average,
            %                       in number of slots. The proportional fair (PF)
            %                       scheduler uses this time constant to calculate the
            %                       average data rate. This name-value argument applies
            %                       when you set the value of the Scheduler argument to
            %                       "ProportionalFair". The default value is 20.
            %   ResourceAllocationType - Specify the resource allocation type as
            %                       0 (resource allocation type 0) or 1 (resource
            %                       allocation type 1). The default value is 1.
            %   MaxNumUsersPerTTI - The allowed maximum number of users per
            %                       transmission time interval (TTI). It is an integer
            %                       scalar that starts from 1. The default value is 8.
            %   FixedMCSIndexDL   - Use modulation and coding scheme (MCS) index for DL
            %                       transmissions without considering any channel
            %                       quality information. The MCS index in the range
            %                       [0-27] and corresponds to a row in the table TS
            %                       38.214 - Table 5.1.3.1-2. The MCS table is stored
            %                       as static property MCSTable of this class. Use
            %                       'MCSIndex' column of the table to set this
            %                       parameter. The default value is empty which means
            %                       that gNB selects the MCS based on CSI-RS
            %                       measurement report.
            %   FixedMCSIndexUL   - Use modulation and coding scheme (MCS) index for UL
            %                       transmissions without considering any channel
            %                       quality information. The MCS index in the range
            %                       [0-27] and corresponds to a row in the table TS
            %                       38.214 - Table 5.1.3.1-2. The MCS table is stored
            %                       as static property MCSTable of this class. Use
            %                       'MCSIndex' column of the table to set this
            %                       parameter. The default value is empty which means
            %                       that gNB selects the MCS based on SRS measurements.
            %   MUMIMOConfigDL    - Set this parameter to enable DL multi-user
            %                       multiple-input and multiple-output (MU-MIMO).
            %                       Specify the parameter as a structure with these
            %                       fields.
            %       MaxNumUsersPaired - Maximum number of users that scheduler can pair
            %                           for a MU-MIMO transmission. It is an integer
            %                           scalar in the range [2-4]. The default value is
            %                           2.
            %       MinNumRBs         - Minimum number of resource blocks (RBs) that a
            %                           UE requires to be considered as a MU-MIMO
            %                           candidate. UE requirement is calculated from
            %                           the buffer occupancy and CQI reported by the
            %                           UE. It is an integer scalar in the range [1-
            %                           NumResourceBlocks]. The default value is 6.
            %       MinCQI            - Minimum channel quality indicator (CQI)
            %                           required for considering a UE as an MU-MIMO
            %                           candidate. It is an integer scalar in the range
            %                           [1, 15]. The default value is 7. For the
            %                           associated CQI table, refer 3GPP TS 38.214
            %                           Table 5.2.2.1-2.
            %       SemiOrthogonalityFactor - Inter-user interference (IUI)
            %                           orthogonality factor. Scheduler uses it to
            %                           decide whether to pair up the UEs for MU-MIMO
            %                           or not. It is a numeric scalar in the range
            %                           [0-1]. Value 0 for a pair of UEs means that
            %                           they are non-orthogonal and value 1 means
            %                           mutual orthogonality between them. The
            %                           orthogonality among the MU-MIMO candidates must
            %                           be greater than this parameter for MU-MIMO
            %                           eligibility. The default value is 0.75.

            validateattributes(obj, {'nrGNB'}, {'vector'}, mfilename, 'obj');
            coder.internal.errorIf(any(~cellfun(@isempty, {obj.CurrentTime})), 'nr5g:nrNode:NotSupportedOperation', 'configureScheduler');
            coder.internal.errorIf(any(~cellfun(@isempty, {obj.ConnectedUEs})), 'nr5g:nrGNB:ConfigSchedulerAfterConnectUE');
            coder.internal.errorIf(any(~[obj.SchedulerDefaultConfig]),'nr5g:nrGNB:MultipleConfigureSchedulerCalls')

            schedulerInfo = struct(Scheduler='RoundRobin', PFSWindowSize=20, ResourceAllocationType=1, ...
                FixedMCSIndexUL=[], FixedMCSIndexDL=[], MaxNumUsersPerTTI=8, ...
                MUMIMOConfigDL=[]);
            % Default values for DL MU-MIMO config parameter
            mumimoConfigDL = struct(MaxNumUsersPaired=2, SemiOrthogonalityFactor=0.75, ...
                MinNumRBs=6, MinCQI=7);
            % Get the user specified parameters for scheduler
            for idx=1:2:nargin-1
                name = varargin{idx};
                if name == "MUMIMOConfigDL"
                    schedulerInfo.MUMIMOConfigDL = nr5g.internal.nrNodeValidation.validateConfigureSchedulerMUMIMOInputs(obj, varargin{idx+1}, mumimoConfigDL);
                else
                    schedulerInfo.(char(name)) = nr5g.internal.nrNodeValidation.validateConfigureSchedulerInputs(name, varargin{idx+1});
                end
            end

            if ~isempty(schedulerInfo.MUMIMOConfigDL)
                [obj.CSIReportType] = deal(2); % Type II feedback for MU-MIMO transmission
            end
            % Get the required parameters for scheduler from node
            schedulerParam = {'DuplexMode', 'NumResourceBlocks', 'DLULConfigTDD', ...
                'NumHARQ', 'NumTransmitAntennas', 'SRSReservedResource', 'SubcarrierSpacing'};
            for nodeIdx = 1:numel(obj)
                gNB = obj(nodeIdx);
                for idx=1:numel(schedulerParam)
                    schedulerInfo.(char(schedulerParam{idx})) = gNB.(char(schedulerParam{idx}));
                end
                % Convert the SCS value from Hz to kHz
                schedulerInfo.SubcarrierSpacing = gNB.SubcarrierSpacing/1e3;
                % Create scheduler object and add it to MAC
                scheduler = nr5g.internal.nrSchedulerStrategy(schedulerInfo);
                addScheduler(gNB.MACEntity, scheduler);
                gNB.SchedulerDefaultConfig = false;
            end
        end
    end

    methods (Access = protected)
        function flag = isInactiveProperty(obj, prop)
            flag = false;
            switch prop
                % DLULConfigTDD is applicable only for TDD
                case "DLULConfigTDD"
                    flag = ~any(strcmpi(obj.DuplexMode, "TDD"));
                case "ConnectedUEs"
                    flag = isempty(obj.ConnectedUEs);
            end
        end
    end
    methods(Access = protected)
        function setLayerInterfaces(obj)
            %setLayerInterfaces Set inter-layer interfaces

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
            registerMACHandle(obj.PhyEntity, @macEntity.rxIndication, @macEntity.srsIndication);

            % Register node callback function at MAC and Phy for:
            % (1) Sending the out-of-band packets from MAC
            % (2) Sending the in-band packets from Phy
            registerOutofBandTxFcn(macEntity, @obj.addToTxBuffer);
            registerTxHandle(phyEntity, @obj.addToTxBuffer);
        end

        function stats = statisticsPerGNB(obj, varargin)
            % Return the statistics for a gNB

            % Create stats structure
            appStat = struct('TransmittedPackets', 0, 'TransmittedBytes', 0, ...
                'ReceivedPackets', 0, 'ReceivedBytes', 0);
            rlcStat = struct('TransmittedPackets', 0, 'TransmittedBytes', 0, ...
                'ReceivedPackets', 0, 'ReceivedBytes', 0, 'DroppedPackets', 0, ...
                'DroppedBytes', 0);
            macStat = struct('TransmittedPackets', 0, 'TransmittedBytes', 0, ...
                'ReceivedPackets', 0, 'ReceivedBytes', 0, 'Retransmissions', 0, ...
                'RetransmissionBytes', 0);
            phyStat = struct('TransmittedPackets', 0, 'ReceivedPackets', 0, ...
                'DecodeFailures', 0);
            stats = struct('ID', obj.ID, 'Name', obj.Name, 'App', appStat, ...
                'RLC', rlcStat, 'MAC', macStat, 'PHY', phyStat);

            if ~isempty(obj.ConnectedUEs) % Check if any UE is connected
                layerStats = struct( 'App', statistics(obj.TrafficManager), ...
                    'RLC', cellfun(@(x) statistics(x), obj.RLCEntity)', 'MAC', statistics(obj.MACEntity), ...
                    'PHY', statistics(obj.PhyEntity));
                destinationIDs = [layerStats.MAC(:).UEID];
                destinationNames = [layerStats.MAC(:).UEName];
                destinationRNTIs = [layerStats.MAC(:).RNTI];
                numDestination = length(destinationIDs);

                % Form application stats
                stats.App = rmfield(layerStats.App, 'TrafficSources');
                if nargin == 2 % "all" option
                    stats.App.Destinations = repmat(struct('UEID', [], 'UEName', [], ...
                        'RNTI', [], 'TransmittedPackets', 0, 'TransmittedBytes', 0 ), ...
                        1, numDestination);
                    for i=1:length(destinationIDs)
                        stats.App.Destinations(i).UEID = destinationIDs(i);
                        stats.App.Destinations(i).UEName = destinationNames(i);
                        stats.App.Destinations(i).RNTI = destinationRNTIs(i);
                    end

                    % Loop over each traffic source and add the stats number to
                    % the corresponding UE
                    for i=1:length(layerStats.App.TrafficSources)
                        trafficSourceStat = layerStats.App.TrafficSources(i);
                        appDestinationID = trafficSourceStat.DestinationNodeID;
                        index = find(destinationIDs == appDestinationID);
                        stats.App.Destinations(index).TransmittedPackets = ...
                            stats.App.Destinations(index).TransmittedPackets + trafficSourceStat.TransmittedPackets;
                        stats.App.Destinations(index).TransmittedBytes = ...
                            stats.App.Destinations(index).TransmittedBytes + trafficSourceStat.TransmittedBytes;
                    end
                end

                % Form RLC stats
                fieldNames = fieldnames(rlcStat);
                if nargin == 2 % "all" option
                    stats.RLC.Destinations = repmat(struct('UEID', [], 'UEName', [], ...
                        'RNTI', [], 'TransmittedPackets', 0, 'TransmittedBytes', 0, ...
                        'ReceivedPackets', 0, 'ReceivedBytes', 0, 'DroppedPackets', 0, ...
                        'DroppedBytes', 0), 1, numDestination);
                end
                for i=1:length(layerStats.RLC)
                    logicalChannelStat = layerStats.RLC(i);
                    nextRLCIndex = 1;
                    for j=1:numel(fieldNames)
                        % Create cumulative stats
                        stats.RLC.(char(fieldNames{j})) = stats.RLC.(char(fieldNames{j})) + ...
                            logicalChannelStat.(char(fieldNames{j}));
                        if nargin == 2 % "all" option
                            if nextRLCIndex
                                nextRLCIndex = 0;  % Execute this block only once for RLC entity
                                rlcDestinationRNTI = logicalChannelStat.RNTI;
                                index = find(destinationRNTIs == rlcDestinationRNTI);
                                stats.RLC.Destinations(index).UEID = destinationIDs(index);
                                stats.RLC.Destinations(index).UEName = destinationNames(index);
                                stats.RLC.Destinations(index).RNTI = rlcDestinationRNTI;
                            end
                            % Set per-destination stats
                            stats.RLC.Destinations(index).(char(fieldNames{j})) = stats.RLC.Destinations(index).(char(fieldNames{j})) + ...
                                logicalChannelStat.(char(fieldNames{j}));
                        end
                    end
                end

                % Form MAC stats
                fieldNames = fieldnames(macStat);
                if nargin == 2 % "all" option
                    stats.MAC.Destinations = repmat(struct('UEID', [], 'UEName', [], ...
                        'RNTI', [], 'TransmittedPackets', 0, 'TransmittedBytes', 0, ...
                        'ReceivedPackets', 0, 'ReceivedBytes', 0, 'Retransmissions', 0, ...
                        'RetransmissionBytes', 0), 1, numDestination);
                end
                for i=1:length(layerStats.MAC)
                    ueMACStats = layerStats.MAC(i);
                    for j=1:numel(fieldNames)
                        % Create cumulative stats
                        stats.MAC.(char(fieldNames{j})) = stats.MAC.(char(fieldNames{j})) + ...
                            ueMACStats.(char(fieldNames{j}));
                        if nargin == 2 % "all" option
                            macDestinationID = ueMACStats.UEID;
                            index = find(destinationIDs == macDestinationID);
                            stats.MAC.Destinations(index).UEID = macDestinationID;
                            stats.MAC.Destinations(index).UEName = destinationNames(index);
                            stats.MAC.Destinations(index).RNTI = destinationRNTIs(index);
                            % Set per-destination stats
                            stats.MAC.Destinations(index).(char(fieldNames{j})) = stats.MAC.Destinations(index).(char(fieldNames{j})) + ...
                                ueMACStats.(char(fieldNames{j}));
                        end
                    end
                end

                % Form PHY stats
                fieldNames = fieldnames(phyStat);
                if nargin == 2 % "all" option
                    stats.PHY.Destinations = repmat(struct('UEID', [], 'UEName', [], ...
                        'RNTI', [], 'TransmittedPackets', 0,'ReceivedPackets', 0, ...
                        'DecodeFailures', 0), 1, numDestination);
                end
                for i=1:length(layerStats.PHY)
                    uePHYStats = layerStats.PHY(i);
                    for j=1:numel(fieldNames)
                        % Create cumulative stats
                        stats.PHY.(char(fieldNames{j})) = stats.PHY.(char(fieldNames{j})) + ...
                            uePHYStats.(char(fieldNames{j}));
                        if nargin == 2 % "all" option
                            % Set per-destination stats
                            phyDestinationID = uePHYStats.UEID;
                            index = find(destinationIDs == phyDestinationID);
                            stats.PHY.Destinations(index).UEID = phyDestinationID;
                            stats.PHY.Destinations(index).UEName = destinationNames(index);
                            stats.PHY.Destinations(index).RNTI = destinationRNTIs(index);
                            stats.PHY.Destinations(index).(char(fieldNames{j})) = stats.PHY.Destinations(index).(char(fieldNames{j})) + ...
                                uePHYStats.(char(fieldNames{j}));
                        end
                    end
                end
            end
        end

        function [srsReservedResource, srsConfiguration] = createSRSConfiguration(obj, varargin)
            %createSRSConfiguration Return SRS reserved resources and the
            %set of SRS resource configurations. When the UEs connect, the
            %scheduler assigns these resources to them. Optionally, you can
            %specify the number of SRS configurations as an argument

            % Set the SRS resource periodicity and offset in terms of slots
            minSRSPeriodicity = 5;
            if strcmp(obj.DuplexMode, "FDD") % FDD
                srsResourcePeriodicity = minSRSPeriodicity;
                srsResourceOffset = 0;
            else % TDD
                dlULConfigTDD = obj.DLULConfigTDD;
                numSlotsDLULPattern = dlULConfigTDD.DLULPeriodicity*(obj.SubcarrierSpacing/15e3);
                % Set SRS resource periodicity as minimum value such that it is at least 5
                % slots and integer multiple of numSlotsDLULPattern
                allowedSRSPeriodicity = [1 2 4 5 8 10 16 20 32 40 64 80 160 320 640 1280 2560];
                allowedSRSPeriodicity = allowedSRSPeriodicity(allowedSRSPeriodicity>=minSRSPeriodicity & ...
                    ~mod(allowedSRSPeriodicity, numSlotsDLULPattern));
                srsResourcePeriodicity = allowedSRSPeriodicity(1);
                % SRS slot offset depends on the occurrence of first slot in
                % TDD pattern with UL symbol. If 'S' slot does not have a
                % UL symbol then SRS is transmitted in the slot after 'S'
                % slot. Otherwise, it is transmitted in the 'S' slot
                if dlULConfigTDD.NumULSymbols == 0
                    srsResourceOffset = dlULConfigTDD.NumDLSlots+1;
                else
                    srsResourceOffset = dlULConfigTDD.NumDLSlots;
                end
            end
            srsReservedResource = [13 srsResourcePeriodicity srsResourceOffset]; % SRS on last symbol

            % The reserved SRS resources are used to generate at least but
            % closest to minSRSConfigCount configurations
            minSRSConfigCount = 16;
            if nargin == 2
                minSRSConfigCount = varargin{1}; % Update as specified
            end
            ktc = 4; % Comb size
            ncsMax = 4; % Maximum cyclic shift (Not using maximum value which could be 12 for ktc=4)
            % Calculate how many slot periodicity each UE must maintain to serve minSRSConfigCount
            srsPeriodicityPerUE = ceil(srsResourcePeriodicity * (minSRSConfigCount/(ktc*ncsMax)));

            % Select the subset of allowed SRS periodicities that are
            % multiple of SRS resource periodicity in terms of slots
            allowedSRSPeriodicity = [1 2 4 5 8 10 16 20 32 40 64 80 160 320 640 1280 2560];
            allowedSRSPeriodicity = allowedSRSPeriodicity(mod(allowedSRSPeriodicity, srsResourcePeriodicity)==0);

            % Select minimum value greater than or equal to 'srsPeriodicityPerUE'
            srsPeriodicityPerUE = allowedSRSPeriodicity(find(allowedSRSPeriodicity>=srsPeriodicityPerUE, 1));

            % Calculate csrs for full bandwidth (or as close as possible to it)
            srsBandwidthMapping = nrSRSConfig.BandwidthConfigurationTable{:,2};
            csrs = find(srsBandwidthMapping <= obj.NumResourceBlocks, 1, 'last') - 1;

            % Populate all SRS configurations by making them unique using
            % slotOffset, comb offset and cyclic shift. gNB fills the
            % number of SRS ports later as the UEs connect, based on
            % respective Tx antenna count on UE
            numSRSConfiguration = (srsPeriodicityPerUE/srsResourcePeriodicity)*ktc*ncsMax;
            srsConfiguration(1:numSRSConfiguration) = nrSRSConfig;
            for i=1:numSRSConfiguration
                srsConfiguration(i).CSRS = csrs;
                srsConfiguration(i).BSRS = 0;
                slotOffset = srsResourceOffset + srsResourcePeriodicity*mod(floor((i-1)/(ktc*ncsMax)), (srsPeriodicityPerUE/srsResourcePeriodicity));
                srsConfiguration(i).SRSPeriod = [srsPeriodicityPerUE slotOffset];
                srsConfiguration(i).KTC = ktc;
                srsConfiguration(i).KBarTC = mod(i-1, ktc);
                srsConfiguration(i).CyclicShift = mod(floor((i-1)/ktc), ncsMax);
            end
        end

        function csirsConfiguration = createCSIRSConfiguration(obj)
            %createCSISRSConfiguration Return common CSI-RS configuration
            %for the cell

            % The default CSI-RS configuration is full-bandwidth. The
            % number of CSI-RS ports equals the number of Tx antennas at
            % gNB. The function sets the periodicity of CSI-RS to 10 slots
            % for FDD. For TDD, the periodicity is a multiple of the length
            % of the DL-UL pattern ( in slots). In this case, the least
            % value of periodicity is 10.

            % Each row contains: AntennaPorts, NumSubcarriers(Max k_i), and
            % NumSymbols(Max l_i) as per TS 38.211 Table 7.4.1.5.3-1
            csirsRowNumberTable = [
                1 1 1; % This row has density 3. Only density as '1' are used.
                1 1 1;
                2 1 1;
                4 1 1;
                4 1 1;
                8 4 1;
                8 2 1;
                8 2 1;
                12 6 1;
                12 3 1;
                16 4 1;
                16 4 1;
                24 3 2;
                24 3 2;
                24 3 1;
                32 4 2;
                32 4 2;
                32 4 1;
                ];

            subcarrierSet = [1 3 5 7 9 11]; % k0 k1 k2 k3 k4 k5
            symbolSet = [0 4]; % l0 l1

            csirsConfiguration = nrCSIRSConfig(CSIRSType="nzp", NumRB=obj.NumResourceBlocks);
            csirsConfiguration.RowNumber = find(csirsRowNumberTable(2:end, 1) == obj.NumTransmitAntennas, 1)+1;
            csirsConfiguration.SubcarrierLocations = subcarrierSet(1:csirsRowNumberTable(csirsConfiguration.RowNumber, 2));
            csirsConfiguration.SymbolLocations = symbolSet(1:csirsRowNumberTable(csirsConfiguration.RowNumber, 3));
            minCSIRSPeriodicity = 10; % Slots
            if strcmp(obj.DuplexMode, "TDD") % TDD
                dlULConfigTDD = obj.DLULConfigTDD;
                numSlotsDLULPattern = dlULConfigTDD.DLULPeriodicity*(obj.SubcarrierSpacing/15e3);
                % Select periodicity such that it is at least 10 and
                % multiple of DL-UL pattern length in slots
                allowedCSIRSPeriodicity = [4,5,8,10,16,20,32,40,64,80,160,320,640];
                allowedCSIRSPeriodicity = allowedCSIRSPeriodicity(allowedCSIRSPeriodicity>=minCSIRSPeriodicity & ...
                    ~mod(allowedCSIRSPeriodicity, numSlotsDLULPattern));
                minCSIRSPeriodicity = allowedCSIRSPeriodicity(1);
            end
            csirsConfiguration.CSIRSPeriod = [minCSIRSPeriodicity 0];
        end

        function updateSRSPeriodicity(obj)
            % Update the SRS periodicity to the next possible higher value
            % to accommodate more UEs

            currentSRSConfigCount = length(obj.SRSOccupancyStatus);
            currentSRSConfig = obj.SRSConfiguration; % Store earlier configurations temporarily
            [~, obj.SRSConfiguration] = obj.createSRSConfiguration(currentSRSConfigCount+1);
            obj.SRSOccupancyStatus = zeros(length(obj.SRSConfiguration), 1);
            % Update the SRS periodicity for already connected UEs. Reuse
            % the earlier configuration by just updating the SRS period
            for j=1:currentSRSConfigCount
                newSRSPeriod = obj.SRSConfiguration(j).SRSPeriod;
                currentSRSConfig(j).SRSPeriod = newSRSPeriod;
                obj.SRSConfiguration(j) = currentSRSConfig(j);
                obj.ConnectedUENodes{j}.updateSRSPeriod(newSRSPeriod);
                obj.MACEntity.updateSRSPeriod(j, newSRSPeriod)
                obj.SRSOccupancyStatus(j) = 1;
            end
        end
    end

    methods(Hidden)
        function flag = intracellPacketRelevance(~, ~)
            %intracellPacketRelevance Returns whether the packet is relevant for the gNB

            % gNB does not reject any intra-cell packet
            flag = 1;
        end
    end

    methods (Static, Hidden)
        function cqiIndex = getCQIIndex(mcsIndex)
            %getCQIIndex Returns the CQI row index based on MCS index

            mcsRow = nr5g.internal.MACConstants.MCSTable(mcsIndex + 1, 1:2);
            % Gets row indices matching the modulation scheme corresponding
            % to mcsIndex
            modSchemeMatch = find(nr5g.internal.MACConstants.CQITable(:, 1)  == mcsRow(1));
            % Among rows with modulation scheme match, find the closet match for code
            % rate (without exceeding the coderate corresponding to
            % mcsIndex)
            cqiRow = find(nr5g.internal.MACConstants.CQITable(modSchemeMatch, 2) > ...
                mcsRow(2),1); % Find the first row with higher coderate
            if ~isempty(cqiRow)
                cqiRow = modSchemeMatch(cqiRow)-1; % Previous row
            else
                cqiRow = modSchemeMatch(end);
            end
            cqiIndex = cqiRow-1; % 0-based indexing
        end

        function mcsTable = getMCSTable()
            % Create TS 38.214 - Table 5.1.3.1-2 MCS table

            tableArray = [(0:27)'  nr5g.internal.MACConstants.MCSTable(1:28, :)];
            columnNames = ["MCS Index", "Modulation Order", "Code Rate x 1024", "Bit Efficiency"];

            % Package array in a table
            mcsTable = array2table(tableArray,"VariableNames",columnNames);
            mcsTable.Properties.VariableNames = columnNames;
            mcsTable.Properties.Description = 'TS 38.214 - Table 5.1.3.1-2: MCS Table';
        end
    end
end