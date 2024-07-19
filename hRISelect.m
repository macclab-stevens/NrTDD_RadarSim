function [RI,PMISet] = hRISelect(carrier,csirs,reportConfig,H,varargin)
% hRISelect Rank indicator calculation
%   [RI,PMISET] = hRISelect(CARRIER,CSIRS,REPORTCONFIG,H) returns the
%   downlink channel rank indicator (RI) value RI and corresponding
%   precoding matrix indicator (PMI) values PMISET, as defined in TS 38.214
%   Section 5.2.2.2, for the specified carrier configuration CARRIER,
%   CSI-RS configuration CSIRS, channel state information (CSI) reporting
%   configuration REPORTCONFIG, and estimated channel information H.
%   
%   CARRIER is a carrier specific configuration object, as described in
%   <a href="matlab:help('nrCarrierConfig')">nrCarrierConfig</a>. Only these object properties are relevant for this
%   function:
%
%   SubcarrierSpacing - Subcarrier spacing in kHz
%   CyclicPrefix      - Cyclic prefix type
%   NSizeGrid         - Number of resource blocks (RBs) in
%                       carrier resource grid
%   NStartGrid        - Start of carrier resource grid relative to common
%                       resource block 0 (CRB 0)
%   NSlot             - Slot number
%   NFrame            - System frame number
%
%   CSIRS is a CSI-RS specific configuration object to specify one or more
%   CSI-RS resources, as described in <a href="matlab:help('nrCSIRSConfig')">nrCSIRSConfig</a>. Only these object
%   properties are relevant for this function:
%
%   CSIRSType           - Type of a CSI-RS resource {'ZP', 'NZP'}
%   CSIRSPeriod         - CSI-RS slot periodicity and offset
%   RowNumber           - Row number corresponding to a CSI-RS resource, as
%                         defined in TS 38.211 Table 7.4.1.5.3-1
%   Density             - CSI-RS resource frequency density
%   SymbolLocations     - Time-domain locations of a CSI-RS resource
%   SubcarrierLocations - Frequency-domain locations of a CSI-RS resource
%   NumRB               - Number of RBs allocated for a CSI-RS resource
%   RBOffset            - Starting RB index of CSI-RS allocation relative
%                         to carrier resource grid
%   For better results, it is recommended to use the same CSI-RS
%   resource(s) that are used for channel estimate, because the resource
%   elements (REs) that does not contain the CSI-RS may have the
%   interpolated channel estimates. Note that the CDM lengths and the
%   number of ports configured for all the CSI-RS resources must be same.
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   NSizeBWP        - Size of the bandwidth part (BWP) in terms of number
%                     of physical resource blocks (PRBs). It must be a
%                     scalar and the value must be in the range 1...275.
%                     Empty ([]) is also supported and it implies that the
%                     value of NSizeBWP is equal to the size of carrier
%                     resource grid
%   NStartBWP       - Starting PRB index of BWP relative to common resource
%                     block 0 (CRB 0). It must be a scalar and the value
%                     must be in the range 0...2473. Empty ([]) is also
%                     supported and it implies that the value of NStartBWP
%                     is equal to the start of carrier resource grid
%   CQITable        - Optional. Channel quality indicator table. It must 
%                     be one of {'table1', 'table2', 'table3'}, as defined
%                     in TS 38.214 Tables 5.2.2.1-2 through 5.2.2.1-4. The
%                     default value is 'table1'.
%   CodebookType    - Optional. The type of codebooks according to which
%                     the CSI parameters must be computed. It must be a
%                     character array or a string scalar. It must be one of
%                     {'Type1SinglePanel', 'Type1MultiPanel', 'Type2', 'eType2'}.
%                     In case of 'Type1SinglePanel', the PMI computation is
%                     performed using TS 38.214 Tables 5.2.2.2.1-1 to
%                     5.2.2.2.1-12. In case of 'Type1MultiPanel', the PMI
%                     computation is performed using TS 38.214 Tables
%                     5.2.2.2.2-1 to 5.2.2.2.2-6. In case of 'Type2' the
%                     computation is performed according to TS 38.214
%                     Section 5.2.2.2.3. In case of 'eType2' the
%                     computation is performed according to TS 38.214
%                     Section 5.2.2.2.5. The default value is
%                     'Type1SinglePanel'
%   PanelDimensions - Antenna panel configuration.
%                        - When CodebookType field is specified as
%                          'Type1SinglePanel' or 'Type2' or 'eType2', this
%                          field is a two-element vector in the form of [N1
%                          N2]. N1 represents the number of antenna
%                          elements in horizontal direction and N2
%                          represents the number of antenna elements in
%                          vertical direction. Valid combinations of
%                          [N1 N2] are defined in TS 38.214 Table 5.2.2.2.1-2.
%                          This field is not applicable when the number of
%                          CSI-RS ports is less than or equal to 2
%                        - When CodebookType field is specified as
%                          'Type1MultiPanel', this field is a three element
%                          vector in the form of [Ng N1 N2], where Ng
%                          represents the number of antenna panels. Valid
%                          combinations of [Ng N1 N2] are defined in TS
%                          38.214 Table 5.2.2.2.2-1
%   PMIMode         - Optional. It represents the mode of PMI reporting. It
%                     must be a character array or a string scalar. It must
%                     be one of {'Subband', 'Wideband'}. The default value
%                     is 'Wideband'
%   SubbandSize     - Subband size for PMI reporting, provided by the
%                     higher-layer parameter NSBPRB. It must be a positive
%                     scalar and must be one of two possible subband sizes,
%                     as defined in TS 38.214 Table 5.2.1.4-2. It is
%                     applicable only when the PMIMode is provided as
%                     'Subband' and the size of BWP is greater than or
%                     equal to 24 PRBs
%   CodebookMode    - Optional. It represents the codebook mode and it must
%                     be a scalar. The value must be one of {1, 2}.
%                        - When CodebookType is specified as
%                          'Type1SinglePanel', this field is applicable
%                          only if the number of transmission layers is 1
%                          or 2 and number of CSI-RS ports is greater than
%                          2
%                        - When CodebookType is specified as
%                          'Type1MultiPanel', this field is applicable for
%                          all the number of transmission layers and the
%                          CodebookMode value 2 is applicable only for the
%                          panel configurations with Ng value 2
%                     This field is not applicable for CodebookType
%                     'Type2' or 'eType2'. The default value is 1
%   CodebookSubsetRestriction
%                   - Optional. It is a binary vector (right-msb) which
%                     represents the codebook subset restriction.
%                        - When the CodebookType is specified as
%                          'Type1SinglePanel' or 'Type1MultiPanel' and the
%                          number of CSI-RS ports is greater than 2, the
%                          length of the input vector must be N1*N2*O1*O2,
%                          where N1 and N2 are panel configurations obtained
%                          from PanelDimensions field and O1 and O2 are the
%                          respective discrete Fourier transform (DFT)
%                          oversampling factors obtained from TS.38.214
%                          Table 5.2.2.2.1-2 for 'Type1SinglePanel' codebook
%                          type or TS.38.214 Table 5.2.2.2.2-1 for
%                          'Type1MultiPanel' codebook type. When the number
%                          of CSI-RS ports is 2, the applicable codebook
%                          type is 'Type1SinglePanel' and the length of the
%                          input vector must be 6, as defined in TS 38.214
%                          Section 5.2.2.2.1
%                        - When CodebookType is specified as 'Type2' or
%                          'eType2', this field is a bit vector which is
%                          obtained by concatenation of two bit vectors
%                          [B1 B2]. B1 is a bit vector of 11 bits (right-msb)
%                          when N2 of the panel dimensions is greater than
%                          1 and 0 bits otherwise.  B2 is a combination of
%                          4 bit vectors, each of length 2*N1*N2. B1
%                          denotes 4 sets of beam groups for which
%                          restriction is applicable. When CodebookType is
%                          specified as 'Type2', B2 denotes the maximum
%                          allowable amplitude for each of the DFT vectors
%                          in each of the respective beam groups denoted by
%                          B1. When CodebookType is specified as 'eType2',
%                          B2 denotes the maximum average coefficient
%                          amplitude for each of the DFT vectors in each of
%                          the respective beam groups denoted by B1. The
%                          default value is empty ([]), which means there
%                          is no codebook subset restriction
%   i2Restriction   - Optional. It is a binary vector which represents the
%                     restricted i2 values in a codebook. Length of the
%                     input vector must be 16. First element of the input
%                     binary vector corresponds to i2 as 0, second element
%                     corresponds to i2 as 1, and so on. Binary value 1
%                     indicates that the precoding matrix associated with
%                     the respective i2 is unrestricted and 0 indicates
%                     that the precoding matrix associated with the
%                     respective i2 is restricted. For a precoding matrices
%                     codebook, if the number of possible i2 values are
%                     less than 16, then only the required binary elements
%                     are considered and the trailing extra elements in the
%                     input vector are ignored. This field is applicable
%                     only when the number of CSI-RS ports is greater than
%                     2 and the CodebookType field is specified as
%                     'Type1SinglePanel'. This field is not applicable when
%                     the CodebookType field is specified as 'Type2'. The
%                     default value is empty ([]), which means there is no
%                     i2 restriction
%   RIRestriction   - Optional. Binary vector to represent the restricted
%                     set of ranks. It is of length 8 when CodebookType is
%                     specified as 'Type1SinglePanel' and of length 4 when
%                     CodebookType is specified as 'Type1MultiPanel' or
%                     'eType2' and of length 2 when the CodebookType is
%                     specified as 'Type2'. The first element corresponds
%                     to rank 1, second element corresponds to rank 2, and
%                     so on. The binary value 0 represents that the
%                     corresponding rank is restricted and the binary value
%                     1 represents that the corresponding rank is
%                     unrestricted. The default value is empty ([]), which
%                     means there is no rank restriction
%   NumberOfBeams   - It is a scalar which represents the number of beams
%                     to be considered in the beam group. This field is
%                     applicable only when the CodebookType is specified as
%                     'Type2'. The value must be one of {2, 3, 4}
%   PhaseAlphabetSize
%                   - Optional. It is a scalar which represents the range
%                     of the phases that are to be considered for the
%                     computation of PMI i2 indices. This field is
%                     applicable only when the CodebookType is specified as
%                     'Type2'. The value must be one of {4, 8}. The value 4
%                     represents the phases corresponding to QPSK and the
%                     value 8 represents the phases corresponding to 8-PSK.
%                     The default value is 4. This field is not a
%                     configurable parameter for 'eType2' and it is fixed
%                     as 16, which corresponds to 16-PSK
%   SubbandAmplitude
%                   - Optional. It is a logical scalar which enables the
%                     reporting of amplitudes per subband when set to true
%                     and disables subband amplitude in PMI reporting when
%                     set to false. The value must be one of {true, false}.
%                     This field is applicable when CodebookType is
%                     specified as 'Type2' and PMIMode is 'Subband'. The
%                     default value is false
%   ParameterCombination
%                   - Optional. It is a positive scalar integer in the
%                     range 1...8. This field is applicable when
%                     CodebookType is specified as 'eType2'. This
%                     parameter defines the number of beams and two other
%                     parameters as defined in TS 38.214 Table 5.2.2.2.5-1.
%                     The default value is 1
%   NumberOfPMISubbandsPerCQISubband
%                   - Optional. It is a positive scalar integer and it must
%                     be either 1 or 2. This field is applicable when
%                     CodebookType is specified as 'eType2'. It represents
%                     the number of PMI subbands within one CQI subband.
%                     The default value is 1.
%
%   H is the channel estimation matrix. It is of size
%   K-by-L-by-nRxAnts-by-Pcsirs, where K is the number of subcarriers in
%   the carrier resource grid, L is the number of orthogonal frequency
%   division multiplexing (OFDM) symbols spanning one slot, nRxAnts is the
%   number of receive antennas, and Pcsirs is the number of CSI-RS antenna
%   ports.
%
%   RI is a scalar which gives the best possible number of transmission
%   layers for the given channel and noise variance conditions. It is in
%   the range 1...8 when CodebookType is specified as 'Type1SinglePanel'
%   and in the range 1...4 when CodebookType is specified as
%   'Type1MultiPanel'.
%
%   PMISET output is a structure representing the set of PMI indices
%   (1-based). The detailed explanation the PMISET is available in the
%   <a href="matlab:help('hDLPMISelect')">hDLPMISelect</a> function.
%
%   [RI,PMISET] = hRISelect(CARRIER,CSIRS,REPORTCONFIG,H,NVAR) specifies
%   the estimated noise variance at the receiver NVAR as a nonnegative
%   scalar. By default, the value of nVar is considered as 1e-10, if it is
%   not given as input.
%
%   [RI,PMISET] = hRISelect(...,NVAR,ALG) also specifies the algorithm ALG
%   as one of 'MaxSINR' or 'MaxSE'. The 'MaxSINR' algorithm selects the
%   rank that maximizes the SINR after PMI precoding. The 'MaxSE' algorithm
%   maximizes the spectral efficiency. The default algorithm is 'MaxSINR'.
%
%   Example:
%   % This example demonstrates how to calculate RI for 4-by-4 MIMO
%   % scenario over TDL Channel.
%
%   % Carrier configuration
%   carrier = nrCarrierConfig;
%
%   % CSI-RS configuration
%   csirs = nrCSIRSConfig;
%   csirs.CSIRSType = {'nzp','nzp'};
%   csirs.RowNumber = [4 4];
%   csirs.Density = {'one','one'};
%   csirs.SubcarrierLocations = {0 0};
%   csirs.SymbolLocations = {0,5};
%   csirs.NumRB = 52;
%   csirs.RBOffset = 0;
%   csirs.CSIRSPeriod = [4 0];
%
%   % Configure the number of transmit and receive antennas
%   nTxAnts = max(csirs.NumCSIRSPorts);
%   nRxAnts = nTxAnts;
%
%   % Configure the number of transmission layers
%   numLayers = 1;
%
%   % Generate CSI-RS indices and symbols
%   csirsInd = nrCSIRSIndices(carrier,csirs);
%   csirsSym = nrCSIRS(carrier,csirs);
%
%   % Resource element mapping
%   txGrid = nrResourceGrid(carrier,nTxAnts);
%   txGrid(csirsInd) = csirsSym;
%
%   % Get OFDM modulation related information
%   OFDMInfo = nrOFDMInfo(carrier);
%
%   % Perform OFDM modulation
%   txWaveform = nrOFDMModulate(carrier,txGrid);
%
%   % Configure the channel parameters.
%   channel = nrTDLChannel;
%   channel.NumTransmitAntennas = nTxAnts;
%   channel.NumReceiveAntennas = nRxAnts;
%   channel.SampleRate = OFDMInfo.SampleRate;
%   channel.DelayProfile = 'TDL-C';
%   channel.DelaySpread = 300e-9;
%   channel.MaximumDopplerShift = 5;
%   chInfo = info(channel);
%
%   % Get the maximum channel delay
%   maxChDelay = chInfo.MaximumChannelDelay;
%
%   % Pass the time-domain waveform through the channel
%   rxWaveform = channel([txWaveform; zeros(maxChDelay,nTxAnts)]);
%
%   % Calculate the timing offset
%   offset = nrTimingEstimate(carrier,rxWaveform,csirsInd,csirsSym);
%
%   % Perform timing synchronization
%   rxWaveform = rxWaveform(1+offset:end,:);
%
%   % Add AWGN
%   SNRdB = 20;          % in dB
%   SNR = 10^(SNRdB/10); % Linear value
%   sigma = 1/(sqrt(2.0*channel.NumReceiveAntennas*double(OFDMInfo.Nfft)*SNR)); % Noise standard deviation
%   rng('default');
%   noise = sigma*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));
%   rxWaveform = rxWaveform + noise;
%   rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
%
%   % Perform the channel estimate
%   [H,nVar] = nrChannelEstimate(rxGrid,csirsInd,csirsSym,'CDMLengths',[2 1]);
%
%   % Configure the required CQI configuration parameters
%   reportConfig.NStartBWP = 2;
%   reportConfig.NSizeBWP = 40;
%   reportConfig.PanelDimensions = [2 1];
%   reportConfig.CodebookMode = 1;
%   reportConfig.PMIMode = 'Wideband';
%   reportConfig.CodebookSubsetRestriction = [];
%   reportConfig.CQIMode = 'Subband';
%   reportConfig.SubbandSize = 4;
%   reportConfig.RIRestriction = [];
%   [RI,PMISet] = hRISelect(carrier,csirs,reportConfig,H,nVar)

%   Copyright 2021-2023 The MathWorks, Inc.

    narginchk(4,6);
 
    % Consider a small noise variance value by default, if the noise
    % variance is not given
    nVar = 1e-10;
    alg = 'MaxSINR';
    if nargin > 4
        nVar = varargin{1};
        if nargin > 5 && ~isempty(varargin{2})
            alg = varargin{2};
        end        
    end

    % Validate the input arguments
    [reportConfig,csirsInd,nVar,alg] = validateInputs(carrier,csirs,reportConfig,H,nVar,alg);

    % Calculate the number of subbands and size of each subband for the
    % given configuration
    PMISubbandInfo = hDLPMISubbandInfo(carrier,reportConfig);

    % Get the number of CSI-RS ports and receive antennas from the
    % dimensions of the channel estimate
    Pcsirs = size(H,4);
    nRxAnts = size(H,3);

    % Calculate the maximum possible transmission rank according to
    % codebook type
    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        % Maximum possible rank is 8 for Type I single-panel codebooks, as
        % defined in TS 38.214 Section 5.2.2.2.1
        maxRank = min([nRxAnts Pcsirs 8]);
    elseif strcmpi(reportConfig.CodebookType,'Type2') ||...
            (strcmpi(reportConfig.CodebookType,'eType2') && any(reportConfig.ParameterCombination == [7 8]))
        % Maximum possible rank is 2 for:
        % - Type II codebooks, as defined in TS 38.214 Section 5.2.2.2.3
        % - Enhanced type II codebooks with parameter combination value
        %   as one of {7, 8}, as defined in TS 38.214 Table 5.2.2.2.5-1
        maxRank = min(nRxAnts,2);
    else
        % Maximum possible rank is 4 for:
        % - Type I multi-panel codebooks, as defined in TS 38.214 Section 5.2.2.2.2
        % - Enhanced type II codebooks with parameter combination value in
        %   the range 1:6, as defined in TS 38.214 Table 5.2.2.2.5-1
        maxRank = min(nRxAnts,4);
    end

    % Check the rank indicator restriction parameter and derive the
    % ranks that are not restricted from usage
    unRestrictedRanks = find(reportConfig.RIRestriction);

    % Compute the set of ranks that are unrestricted and are less than
    % or equal to the maximum possible rank
    validRanks = intersect(unRestrictedRanks,1:maxRank);
    
    % Initialize outputs
    [RI, PMISet] = initOutputs(reportConfig,PMISubbandInfo);

    if ~isempty(validRanks) && ~isempty(csirsInd)
        if strcmpi(alg,'MaxSINR')
            [RI,PMISet] = riSelectPMI(carrier,csirs,reportConfig,H,nVar,validRanks,PMISubbandInfo);
        else % maxSE
            [RI,PMISet] = riSelectCQI(carrier,csirs,reportConfig,H,nVar,validRanks,PMISubbandInfo);
        end
    end
end

% Selection of rank indicator based on maximizing SINR after precoding
function [RI,PMISet] = riSelectPMI(carrier,csirs,reportConfig,H,nVar,validRanks,PMISubbandInfo)

    % Initialize the best SINR value as -Inf and totalSINR
    % corresponding to each rank as NaN
    bestSINR = -Inf;
    totalSINR = NaN(1,max(validRanks));

    % Initialize outputs
    [RI, PMISet] = initOutputs(reportConfig,PMISubbandInfo);

    % For each valid rank, compute the PMI indices set along with the
    % corresponding best SINR values. Then, find the rank which gives
    % the maximum total SINR
    for rankIdx = validRanks
        % PMI selection
        [PMI,PMIInfo] = hDLPMISelect(carrier,csirs,reportConfig,rankIdx,H,nVar);
    
        % Initialize the SINRs parameter
        subbandSINRs = NaN(PMISubbandInfo.NumSubbands,rankIdx);
        if ~all(isnan(PMI.i1))
            % Extract the subband SINR values across all the layers
            % corresponding to the reported PMI
            for idx = 1:PMISubbandInfo.NumSubbands
                if ~all(isnan((PMI.i2(:,idx))))
                    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
                        subbandSINRs(idx,:) = PMIInfo.SINRPerSubband(idx,:,PMI.i2(idx),PMI.i1(1),PMI.i1(2),PMI.i1(3))*rankIdx;
                    elseif strcmpi(reportConfig.CodebookType,'Type1MultiPanel')
                        subbandSINRs(idx,:) = PMIInfo.SINRPerSubband(idx,:,PMI.i2(1,idx),PMI.i2(2,idx),PMI.i2(3,idx),PMI.i1(1),PMI.i1(2),PMI.i1(3),PMI.i1(4),PMI.i1(5),PMI.i1(6))*rankIdx;
                    else % Type II and enhanced type II codebooks
                        subbandSINRs(idx,:) = PMIInfo.SINRPerSubband(idx,:)*rankIdx;
                    end
                end
            end
    
            % Compute the mean value of the SINRs across all the subbands
            layerSINRs =  mean(subbandSINRs,1,'omitnan');
            % Compute the total SINR as the sum of layerSINRs. Consider
            % only the layers with SINR value >= 0 dB or
            % linear value >= 1
            totalSINR(rankIdx) = sum(layerSINRs(layerSINRs>=1));
        end
        if totalSINR(rankIdx) > bestSINR + 0.1
            bestSINR = totalSINR(rankIdx);
            RI = rankIdx;
            PMISet = PMI;
        end
    end

end

% Selection of rank indicator based on maximizing spectral efficiency
function [RI,PMISet] = riSelectCQI(carrier,csirs,reportConfig,H,nVar,validRanks,PMISubbandInfo)

    % Initialize outputs
    [~, PMISet] = initOutputs(reportConfig,PMISubbandInfo);

    % For each valid rank, select the best CQI. Then, find the rank
    % that maximizes modulation and coding efficiency
    maxRank = max(validRanks);
    efficiency = NaN(maxRank,1);
    for rank = validRanks
        % Determine the CQI and PMI for the current rank
        [cqi,pmi(rank),cqiInfo] = hCQISelect(carrier,csirs,reportConfig,rank,H,nVar); %#ok<AGROW>
    
        % Get wideband CQI
        cqiWideband = cqi(1,:);
    
        % If the wideband CQI is appropriate, calculate the efficiency
        if all(cqiWideband ~= 0)
            if ~any(isnan(cqiWideband))
                % Calculate throughput-related metric using number of
                % layers, code rate and modulation, and estimated BLER
                blerWideband = cqiInfo.TransportBLER(1,:);
                ncw = numel(cqiWideband);
                cwLayers = floor((rank + (0:ncw-1)) / ncw);
                mcs = hCQITables(reportConfig.CQITable,cqiWideband);
                eff = cwLayers .* (1 - blerWideband) * mcs(:,4);
                efficiency(rank) = eff;
            end
        else
            efficiency(rank) = 0;
        end
    end
    
    % Return the rank that maximizes the spectral efficiency and the
    % corresponding PMI.
    [maxEff,RI] = max(efficiency);
    if ~isnan(maxEff)
        PMISet = pmi(RI);
    end

end

function [RI, PMISet] = initOutputs(reportConfig,PMISubbandInfo)
%   [RI, PMISET] = initOutputs(REPORTCONFIG,PMISUBBANDINFO) initializes the
%   rank and PMI set values with NaNs.

    RI = NaN;
    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        PMISet.i1 = NaN(1,3);
        PMISet.i2 = NaN*ones(1,PMISubbandInfo.NumSubbands);
    else
        PMISet.i1 = NaN(1,6);
        PMISet.i2 = NaN*ones(3,PMISubbandInfo.NumSubbands);
    end

end

function [reportConfig,csirsInd,nVar,alg] = validateInputs(carrier,csirs,reportConfig,H,nVar,alg)
%   [REPORTCONFIG,CSIRSIND,NVAR,ALG] = validateInputs(CARRIER,CSIRS,REPORTCONFIG,H,NVAR,ALG)
%   validates the inputs arguments and returns the validated CSI report
%   configuration structure REPORTCONFIG along with the CSI-RS indices
%   CSIRSIND, the noise variance NVAR and algorithm ALG.

    fcnName = 'hRISelect';
    validateattributes(carrier,{'nrCarrierConfig'},{'scalar'},fcnName,'CARRIER');
    % Validate 'csirs'
    validateattributes(csirs,{'nrCSIRSConfig'},{'scalar'},fcnName,'CSIRS');
    if ~isscalar(unique(csirs.NumCSIRSPorts))
        error('nr5g:hRISelect:InvalidCSIRSPorts',...
            'All the CSI-RS resources must be configured to have the same number of CSI-RS ports.');
    end
    if ~iscell(csirs.CDMType)
        cdmType = {csirs.CDMType};
    else
        cdmType = csirs.CDMType;
    end
    if ~all(strcmpi(cdmType,cdmType{1}))
        error('nr5g:hRISelect:InvalidCSIRSCDMTypes',...
            'All the CSI-RS resources must be configured to have the same CDM lengths.');
    end

    % Validate 'reportConfig'
    % Validate 'NSizeBWP'
    if ~isfield(reportConfig,'NSizeBWP')
        error('nr5g:hRISelect:NSizeBWPMissing','NSizeBWP field is mandatory.');
    end
    nSizeBWP = reportConfig.NSizeBWP;
    if ~(isnumeric(nSizeBWP) && isempty(nSizeBWP))
        validateattributes(nSizeBWP,{'double','single'},{'scalar','integer','positive','<=',275},fcnName,'the size of BWP');
    else
        nSizeBWP = carrier.NSizeGrid;
    end
    % Validate 'NStartBWP'
    if ~isfield(reportConfig,'NStartBWP')
        error('nr5g:hRISelect:NStartBWPMissing','NStartBWP field is mandatory.');
    end
    nStartBWP = reportConfig.NStartBWP;
    if ~(isnumeric(nStartBWP) && isempty(nStartBWP))
        validateattributes(nStartBWP,{'double','single'},{'scalar','integer','nonnegative','<=',2473},fcnName,'the start of BWP');
    else
        nStartBWP = carrier.NStartGrid;
    end
    if nStartBWP < carrier.NStartGrid
        error('nr5g:hRISelect:InvalidNStartBWP',...
            ['The starting resource block of BWP ('...
            num2str(nStartBWP) ') must be greater than '...
            'or equal to the starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ').']);
    end
    % Check whether BWP is located within the limits of carrier or not
    if (nSizeBWP + nStartBWP)>(carrier.NStartGrid + carrier.NSizeGrid)
        error('nr5g:hRISelect:InvalidBWPLimits',['The sum of starting resource '...
            'block of BWP (' num2str(nStartBWP) ') and the size of BWP ('...
            num2str(nSizeBWP) ') must be less than or equal to '...
            'the sum of starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ') and size of the carrier ('...
            num2str(carrier.NSizeGrid) ').']);
    end
    reportConfig.NStartBWP = nStartBWP;
    reportConfig.NSizeBWP = nSizeBWP;

    % Check for the presence of 'CodebookType' field
    if isfield(reportConfig,'CodebookType')
        reportConfig.CodebookType = validatestring(reportConfig.CodebookType,{'Type1SinglePanel','Type1MultiPanel','Type2','eType2'},fcnName,'CodebookType field');
    else
        reportConfig.CodebookType = 'Type1SinglePanel';
    end

    % Validate 'alg'
    alg = validatestring(alg,{'MaxSINR','MaxSE'},fcnName,'ALG');
    maxSEFlag = strcmpi(alg,'MaxSE');
    if maxSEFlag
        % Validate 'CQIMode'
        if isfield(reportConfig,'CQIMode')
            reportConfig.CQIMode = validatestring(reportConfig.CQIMode,{'Wideband','Subband'},fcnName,'CQIMode field');
        else
            reportConfig.CQIMode = 'Wideband';
        end

        % Validate 'CQITable'
        if isfield(reportConfig,'CQITable')
            reportConfig.CQITable = validatestring(reportConfig.CQITable,{'table1','table2','table3'},fcnName,'CQITable field');
        else
            reportConfig.CQITable = 'table1';
        end
    end

    % Validate 'PMIMode'
    if isfield(reportConfig,'PMIMode')
        reportConfig.PMIMode = validatestring(reportConfig.PMIMode,{'Wideband','Subband'},fcnName,'PMIMode field');
    else
        reportConfig.PMIMode = 'Wideband';
    end

    % Validate 'SubbandSize'
    NSBPRB = [];
    if strcmpi(reportConfig.PMIMode,'Subband') || (maxSEFlag && strcmpi(reportConfig.CQIMode,'Subband'))
        if nSizeBWP >= 24
            if ~isfield(reportConfig,'SubbandSize')
                error('nr5g:hRISelect:SubbandSizeMissing',...
                    ['For the subband mode, SubbandSize field is '...
                    'mandatory when the size of BWP is more than 24 PRBs.']);
            end
            validateattributes(reportConfig.SubbandSize,{'double','single'},...
                {'real','scalar'},fcnName,'SubbandSize field');
            NSBPRB = reportConfig.SubbandSize;

            % Validate the subband size, based on the size of BWP
            % BWP size ranges
            nSizeBWPRange = [24  72;
                             73  144;
                             145 275];
            % Possible values of subband size
            nSBPRBValues = [4  8;
                            8  16;
                            16 32];
            bwpRangeCheck = (nSizeBWP >= nSizeBWPRange(:,1)) & (nSizeBWP <= nSizeBWPRange(:,2));
            validNSBPRBValues = nSBPRBValues(bwpRangeCheck,:);
            if ~any(NSBPRB == validNSBPRBValues)
                error('nr5g:hRISelect:InvalidSubbandSize',['For the configured BWP size (' num2str(nSizeBWP) ...
                    '), subband size (' num2str(NSBPRB) ') must be ' num2str(validNSBPRBValues(1)) ...
                    ' or ' num2str(validNSBPRBValues(2)) '.']);
            end
        end        
    end
    reportConfig.SubbandSize = NSBPRB;

    % If 'PRGSize' field is present, update it as empty, since it is not
    % required for RI computation
    if isfield(reportConfig,'PRGSize')
        reportConfig.PRGSize = [];
    end

    % Validate 'RIRestriction'
    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        maxRank = 8;
        codebookType = 'type I single-panel';
    elseif strcmpi(reportConfig.CodebookType,'Type1MultiPanel')
        maxRank = 4;
        codebookType = 'type I multi-panel';
    elseif strcmpi(reportConfig.CodebookType,'Type2')
        maxRank = 2;
        codebookType = 'type II';
    else % Enhanced type II codebook
        maxRank = 4;
        codebookType = 'enhanced type II';       
    end

    if isfield(reportConfig,'RIRestriction') && ~isempty(reportConfig.RIRestriction)
        validateattributes(reportConfig.RIRestriction,{'numeric'},{'vector','binary','numel',maxRank},fcnName,['RIRestriction field in ' codebookType ' codebook type']);
    else
        reportConfig.RIRestriction = ones(1,maxRank);
    end

    if strcmpi(reportConfig.CodebookType,'eType2')
        % Validate 'ParameterCombination'
        if isfield(reportConfig,'ParameterCombination')
            validateattributes(reportConfig.ParameterCombination,{'numeric'}, ...
                {'scalar','integer','positive','<=',8},fcnName,...
                ['PARAMETERCOMBINATION(' num2str(reportConfig.ParameterCombination) ') when codebook type is "eType2"']);
        else
            reportConfig.ParameterCombination = 1; % Default value
        end
    end

    % Validate 'H'
    validateattributes(H,{'double','single'},{},fcnName,'H');
    validateattributes(numel(size(H)),{'double'},{'>=',2,'<=',4},fcnName,'number of dimensions of H');

    % Ignore zero-power (ZP) CSI-RS resources, as they are not used for CSI
    % estimation
    if ~iscell(csirs.CSIRSType)
        csirs.CSIRSType = {csirs.CSIRSType};
    end

    numZPCSIRSRes = sum(strcmpi(csirs.CSIRSType,'zp'));
    tempInd = nrCSIRSIndices(carrier,csirs,"IndexStyle","subscript","OutputResourceFormat","cell");
    tempInd = tempInd(numZPCSIRSRes+1:end)';
    csirsInd = zeros(0,3);
    if ~isempty(tempInd)
        csirsInd = cell2mat(tempInd);
    end
    if ~isempty(csirsInd)
        K = carrier.NSizeGrid*12;
        L = carrier.SymbolsPerSlot;
        NumCSIRSPorts = csirs.NumCSIRSPorts(1);
        validateattributes(H,{class(H)},{'size',[K L NaN NumCSIRSPorts]},fcnName,'H');
    end

    % Validate 'nVar'
    validateattributes(nVar,{'double','single'},{'scalar','real','nonnegative','finite'},fcnName,'NVAR');
    % Clip 'nVar' to a small noise variance to avoid +/-Inf outputs
    if nVar < 1e-10
        nVar = 1e-10;
    end
end