function [CQI,PMISet,CQIInfo,PMIInfo] = hCQISelect(carrier,varargin)
% hCQISelect PDSCH Channel quality indicator calculation
%   [CQI,PMISET,CQIINFO,PMIINFO] = hCQISelect(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H)
%   returns channel quality indicator (CQI) values CQI and precoding matrix
%   indicator (PMI) values PMISET, as defined in TS 38.214 Section 5.2.2.2,
%   for the specified carrier configuration CARRIER, CSI-RS configuration
%   CSIRS, channel state information (CSI) reporting configuration
%   REPORTCONFIG, number of transmission layers NLAYERS, and estimated
%   channel information H. The function also returns the additional
%   information about the signal to interference and noise ratio (SINR)
%   values that are used for the CQI computation and PMI computation.
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
%                     default value is 'table1'
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
%   CQIMode         - Optional. It represents the mode of CQI reporting. It
%                     must be a character array or a string scalar. It must
%                     be one of {'Subband', 'Wideband'}. The default value
%                     is 'Wideband'
%   PMIMode         - Optional. It represents the mode of PMI reporting. It
%                     must be a character array or a string scalar. It must
%                     be one of {'Subband', 'Wideband'}. The default value
%                     is 'Wideband'
%   SubbandSize     - Subband size for CQI or PMI reporting, provided by
%                     the higher-layer parameter NSBPRB. It must be a
%                     positive scalar and must be one of two possible
%                     subband sizes, as defined in TS 38.214 Table
%                     5.2.1.4-2. It is applicable only when either CQIMode
%                     or PMIMode are provided as 'Subband' and the size of
%                     BWP is greater than or equal to 24 PRBs
%   PRGSize         - Optional. Precoding resource block group (PRG) size
%                     for CQI calculation, provided by the higher-layer
%                     parameter pdsch-BundleSizeForCSI. This field is
%                     applicable to the CSI report quantity cri-RI-i1-CQI,
%                     as defined in TS 38.214 Section 5.2.1.4.2. This
%                     report quantity expects only the i1 set of PMI to be
%                     reported as part of CSI parameters and PMI mode is
%                     expected to be 'Wideband'. But, for the computation
%                     of the CQI in this report quantity, PMI i2 values are
%                     needed for each PRG. Hence, the PMI output, when this
%                     field is configured, is given as a set of i2 values,
%                     one for each PRG of the specified size. It must be a
%                     scalar and it must be one of {2, 4}. Empty ([]) is
%                     also supported to represent that this field is not
%                     configured by higher layers. If it is present and not
%                     configured as empty, the CQI values are computed
%                     according to the configured CQIMode and the PMI value
%                     is reported for each PRG irrespective of PMIMode.
%                     This field is applicable only when the CodebookType
%                     is configured as 'Type1SinglePanel'. The default
%                     value is []
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
%                     CodebookType is specified as 'Type2'. The default
%                     value is empty ([]), which means there is no i2
%                     restriction
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
%                     The default value is 1
%
%   The detailed explanation of the CodebookSubsetRestriction field is
%   present in <a href="matlab:help('hDLPMISelect')">hDLPMISelect</a> function.
%
%   NLAYERS is a scalar representing the number of transmission layers.
%   When CodebookType is specified as 'Type1SinglePanel', its value must be
%   in the range of 1...8. When CodebookType is specified as
%   'Type1MultiPanel', its value must be in the range of 1...4. When
%   CodebookType is specified as 'Type2', its value must be in the range of
%   1...2. When CodebookType is specified as 'eType2', its value must be in
%   the range of 1...4.
%
%   H is the channel estimation matrix. It is of size
%   K-by-L-by-nRxAnts-by-Pcsirs, where K is the number of subcarriers in
%   the carrier resource grid, L is the number of orthogonal frequency
%   division multiplexing (OFDM) symbols spanning one slot, nRxAnts is the
%   number of receive antennas, and Pcsirs is the number of CSI-RS antenna
%   ports. Note that the number of transmission layers provided must be
%   less than or equal to min(nRxAnts,Pcsirs).
%
%   CQI output is a 2-dimensional matrix of size 1-by-numCodewords when CQI
%   reporting mode is 'Wideband' and (numSubbands+1)-by-numCodewords when
%   CQI reporting mode is 'Subband'. numSubbands is the number of subbands
%   and numCodewords is the number of codewords. The first row consists of
%   'Wideband' CQI value and if the CQI mode is 'Subband', the 'Wideband'
%   CQI value is followed by the subband differential CQI values for each
%   subband. The subband differential values are scalars ranging from 0 to
%   3 and these values are computed based on the offset level, as defined
%   in TS 38.214 Table 5.2.2.1-1, where
%   subband CQI offset level = subband CQI index - wideband CQI index.
%
%   Note that when the PRGSize field in the reportConfig is configured as
%   other than empty, it is assumed that the report quantity as reported by
%   the higher layers is 'cri-RI-i1-CQI'. In this case the SINR values for
%   the CQI computation are chosen based on the i1 values reported in
%   PMISet and a valid random i2 value from all the reported i2 values in
%   the PMISet. In this case, i2 values reported in the PMISet correspond
%   to each PRG. When CQI reporting mode is 'Wideband', one i2 value is
%   chosen randomly, for the entire BWP, from the set of i2 values of all
%   PRGs. When CQI reporting mode is subband, one i2 value is chosen
%   randomly, for each subband, from the set of PRGs that span the
%   particular subband. Considering this set of i2 values for indexing, the
%   corresponding SINR values are used for CQI computation.
%
%   PMISET output is a structure representing the set of PMI indices
%   (1-based). The detailed explanation of PMISET is available in the
%   <a href="matlab:help('hDLPMISelect')">hDLPMISelect</a> function.
%
%   CQIINFO is an output structure for the CQI information with these
%   fields:
%   SINRPerSubbandPerCW - It represents the linear SINR values in each
%                         subband for all the codewords. It is a
%                         two-dimensional matrix of size
%                            - 1-by-numCodewords, when CQI reporting mode
%                              is 'Wideband'
%                            - (numSubbands + 1)-by-numCodewords, when
%                              CQI reporting mode is 'Subband'
%                         Each column of the matrix contains wideband SINR
%                         value (the average SINR value across all
%                         subbands) followed by the SINR values of each
%                         subband. The SINR value in each subband is taken
%                         as an average of SINR values of all the REs
%                         across the particular subband spanning one slot
%   SINRPerRBPerCW      - It represents the linear SINR values in each
%                         RB for all the codewords. It is a
%                         three-dimensional matrix of size
%                         NSizeBWP-by-L-by-numCodewords. The SINR value in
%                         each RB is taken as an average of SINR values of
%                         all the REs across the RB spanning one slot
%   SubbandCQI          - It represents the subband CQI values. It is a
%                         two-dimensional matrix of size
%                            - 1-by-numCodewords, when CQI reporting mode
%                              is 'Wideband' 
%                            - (numSubbands + 1)-by-numCodewords, when
%                              CQI reporting mode is 'Subband'
%                         Each column of the matrix contains the absolute
%                         CQI value of wideband followed by the absolute
%                         CQI values corresponding to each subband
%   TransportBLER       - Estimated transport block error rate (BLER) for
%                         each element in SubbandCQI
%
%   Note that the CQI output and all the fields of CQIINFO are returned as
%   NaNs for these cases:
%      - When CSI-RS is not present in the operating slot or in the BWP
%      - When the reported PMISet is all NaNs
%   Also note that the subband differential CQI value or SubbandCQI value
%   is reported as NaNs in the subbands where CSI-RS is not present.
%
%   PMIINFO is an output structure with the information about SINR values,
%   codebook, and the precoding matrix. The detailed explanation for
%   PMIINFO is given under INFO output in the <a href="matlab:help('hDLPMISelect')">hDLPMISelect</a> function.
%
%   [CQI,PMISET,CQIINFO,PMIINFO] = hCQISelect(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H,NVAR)
%   specifies the estimated noise variance at the receiver NVAR as a
%   nonnegative scalar. By default, the value of nVar is considered as
%   1e-10, if it is not given as input.
%
%   [CQI,PMISET,CQIINFO,PMIINFO] = hCQISelect(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H,NVAR,SINRTABLE)
%   also specifies the SINR lookup table SINRTABLE as input.
%
%   SINRTABLE is a vector of 15 SINR values in decibels (dB), each value
%   corresponding to a CQI value that is computed according to the block
%   error rate (BLER) condition as mentioned in TS 38.214 Section 5.2.2.1.
%
%   [CQI,PMISET,CQIINFO,PMIINFO] = hCQISelect(CARRIER,BWP,CQICONFIG,CSIRSIND,H,NVAR) 
%   returns CQI and PMI values along with SINR related information by
%   considering these inputs. This syntax only supports the SISO case.
%
%   BWP is a structure with these fields:
%   NStartBWP      - The starting PRB index of the BWP relative to the
%                    CRB 0
%   NSizeBWP       - The size of BWP in terms of number of PRBs
%
%   CQICONFIG is a structure of configuration parameters required for CQI
%   reporting with these fields:
%   CQIMode        - Optional. It represents the mode of CQI reporting. It
%                    must be a character array or a string scalar. It must
%                    be one of {'Subband', 'Wideband'}. The default value
%                    is 'Wideband'
%   NSBPRB         - Subband size, as provided by the higher layers, is
%                    one of two possible subband sizes according to TS
%                    38.214 Table 5.2.1.4-2. This field is applicable only
%                    when CQIMode is 'Subband'
%   SINR90pc       - Optional. Vector of 15 SINR values in dB. Each value
%                    corresponds to a CQI value at which the BLER must be a
%                    maximum of 0.1. This condition implies that the
%                    throughput must be a minimum of 90 percent when
%                    operated at the SINR
%   Note that NSBPRB and SINR90pc fields are equivalent to SubbandSize and
%   SINRTable inputs respectively, when CSI-RS object is specified as an
%   input in the syntax.
%
%   CSIRSIND are the CSI-RS indices spanning one slot. These indices are
%   1-based and are in concatenated format. It is recommended to give the
%   CSI-RS indices corresponding to row numbers 1 or 2 (since this
%   syntax supports only SISO) and that are used to compute the channel
%   estimate for better results.
%
%   Note that the noise variance NVAR is a mandatory input in this syntax.
%
%   CQI by definition, is a scalar value ranging from 0 to 15 which
%   indicates highest modulation and coding scheme (MCS), suitable for the
%   downlink transmission in order to achieve the required BLER condition.
%
%   According to TS 38.214 Section 5.2.2.1, the user equipment (UE) reports
%   highest CQI index which satisfies the condition where a single physical
%   downlink shared channel (PDSCH) transport block with a combination of
%   modulation scheme, target code rate and transport block size
%   corresponding to the CQI index, and occupying a group of downlink PRBs
%   termed the CSI reference resource (as defined in TS 38.214 Section
%   5.2.2.5), could be received with a transport block error probability
%   not exceeding:
%      -   0.1, when the higher layer parameter cqi-Table in
%          CSI-ReportConfig configures 'table1' (corresponding to TS 38.214
%          Table 5.2.2.1-2), or 'table2' (corresponding to TS 38.214 Table
%          5.2.2.1-3)
%      -   0.00001, when the higher layer parameter cqi-Table in
%          CSI-ReportConfig configures 'table3' (corresponding to TS 38.214
%          Table 5.2.2.1-4)
%
%   The CQI indices and their interpretations are given in TS 38.214 Table
%   5.2.2.1-2 or TS 38.214 Table 5.2.2.1-4, for reporting CQI based on
%   QPSK, 16QAM, 64QAM. The CQI indices and their interpretations are given
%   in TS 38.214 Table 5.2.2.1-3, for reporting CQI based on QPSK, 16QAM,
%   64QAM and 256QAM.
%
%   Note that the function only supports the multiple input multiple output
%   (MIMO) scenario with PMI using type I single-panel codebooks and type I
%   multi-panel codebooks.
%
%   % Example:
%   % This example demonstrates how to calculate CQI for the 4-by-4 MIMO
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
%   [CQI,PMISet,CQIInfo,PMIInfo] = hCQISelect(carrier,csirs,reportConfig,numLayers,H,nVar)

%   Copyright 2019-2023 The MathWorks, Inc.

    narginchk(5,7)
    % Extract the input arguments 
    [reportConfig,nLayers,H,nVar,SINRTable,isCSIRSObjSyntax,nTxAnts,csirsInd,csirs,inputSINRTable] = parseInputs(carrier,varargin);

    % Validate the input arguments
    [reportConfig,SINRTable,nVar] = validateInputs(carrier,reportConfig,nLayers,H,nVar,SINRTable,nTxAnts,csirsInd,isCSIRSObjSyntax);
 
    % Calculate the number of subbands and size of each subband for the
    % given CQI configuration and the PMI configuration. If PRGSize
    % parameter is present and configured with a value other than empty,
    % the PMISubbandInfo consists of PRG related information, otherwise it
    % contains PMI subbands related information
    [CQISubbandInfo,PMISubbandInfo] = getDownlinkCSISubbandInfo(reportConfig);

    % Calculate the number of codewords for the given number of layers. For
    % number of layers greater than 4, there are two codewords, else one
    % codeword
    numCodewords = ceil(nLayers/4);

    % Calculate the start of BWP relative to the carrier
    bwpStart = reportConfig.NStartBWP - carrier.NStartGrid;

    if ~isCSIRSObjSyntax
        % Calculate the SINR and CQI values according to the syntax with
        % CSI-RS indices. It supports the computation of the CQI values for
        % SISO case

        % Consider W as 1 in SISO case
        W = 1;

        % Consider only the unique positions for all CSI-RS ports to avoid
        % repetitive calculation
        csirsInd = unique(csirsInd);

        % Convert CSI-RS indices to subscripts in 1-based notation
        [csirsIndSubs_kTemp,csirsIndSubs_lTemp,~] = ind2sub([carrier.NSizeGrid*12 carrier.SymbolsPerSlot nTxAnts],csirsInd);
        % Consider the CSI-RS indices present only in the BWP
        indInBWP = (csirsIndSubs_kTemp >= bwpStart*12 + 1) & csirsIndSubs_kTemp <= (bwpStart + reportConfig.NSizeBWP)*12;
        csirsIndSubs_k = csirsIndSubs_kTemp(indInBWP);
        csirsIndSubs_l = csirsIndSubs_lTemp(indInBWP);
        csirsIndSubs_p = ones(size(csirsIndSubs_k));
        % Make the CSI-RS subscripts relative to BWP start
        csirsIndSubs_k = csirsIndSubs_k - bwpStart*12;
        csirsInd_len = length(csirsIndSubs_k);
        if isempty(csirsIndSubs_k) || (nVar == 0)
            % Report PMI related outputs as all NaNs, if there are no
            % CSI-RS resources present in the BWP or the noise variance
            % value is zero
            PMISet.i1 = [NaN NaN NaN];
            PMISet.i2 = NaN(1,PMISubbandInfo.NumSubbands);

            PMIInfo.SINRPerSubband = NaN(PMISubbandInfo.NumSubbands,nLayers);
            PMIInfo.SINRPerRE = NaN(csirsInd_len,nLayers);
            PMIInfo.SINRPerREPMI = NaN(csirsInd_len,nLayers);
            PMIInfo.W = W;
            PMIInfo.CSIRSIndices = [csirsIndSubs_k csirsIndSubs_l csirsIndSubs_p];

            if CQISubbandInfo.NumSubbands == 1
                % Convert the numSubbands to 0 to report only the wideband CQI
                % index in case of wideband mode
                numSubbands = 0;
            else
                numSubbands = CQISubbandInfo.NumSubbands;
            end
            % Report CQI and the CQI information structure parameters as NaN
            CQI = NaN(numSubbands+1,numCodewords);
            CQIInfo.SINRPerSubbandPerCW = NaN(numSubbands+1,numCodewords);
            CQIInfo.SINRPerRBPerCW = NaN(reportConfig.NSizeBWP,carrier.SymbolsPerSlot,numCodewords);
            CQIInfo.SubbandCQI = NaN(numSubbands+1,numCodewords);
            return;

        else
            % Initialize the SINRsperRE variable to store the SINR values
            % at CSI-RS RE locations indicated by csirsIndSubs_k
            SINRsperRE = zeros(length(csirsIndSubs_k),1);
            % Loop over all the REs in which CSI-RS is present
            for reIdx = 1: numel(csirsIndSubs_k)
                prgIdx = csirsIndSubs_k(reIdx);
                l = csirsIndSubs_l(reIdx);
                Htemp = H(prgIdx,l);
                % Compute the SINR values at each subcarrier location where
                % CSI-RS is present
                SINRsperRE(reIdx) = hPrecodedSINR(Htemp,nVar,W);
            end

            % Consider the PMI indices as all ones for SISO case
            PMI.i1 = [1 1 1];
            PMI.i2 = ones(1,CQISubbandInfo.NumSubbands);

            % Compute the SINR values in subband level granularity
            % according to CQI mode
            SINRperSubbandperCW = getSubbandSINR(SINRsperRE,CQISubbandInfo,csirsIndSubs_k); % Corresponds to single codeword

            % Compute wideband SINR as a mean of subband SINR values and
            % place it in position 1
            SINRperSubbandperCW = [mean(SINRperSubbandperCW,'omitnan'); SINRperSubbandperCW];

            % Get the SINR value per RB spanning one slot
            SINRsperRBperCW = getSINRperRB(SINRsperRE,csirsIndSubs_k,csirsIndSubs_l,reportConfig.NSizeBWP,carrier.SymbolsPerSlot);

            % This syntax does not consider the PMI mode. The PMISet and
            % PMIInfo output are returned by considering the PMI mode as
            % 'Wideband'
            PMISet.i1 = PMI.i1;
            PMISet.i2 = 1;

            PMIInfo.SINRPerRE = SINRsperRE;
            PMIInfo.SINRPerREPMI = SINRsperRE;
            PMIInfo.SINRPerSubband = SINRperSubbandperCW(1,:);
            PMIInfo.W = W;
            PMIInfo.CSIRSIndices = [csirsIndSubs_k csirsIndSubs_l csirsIndSubs_p];
        end
    else
        % Calculate the SINR and CQI values according to the syntax with
        % the CSI-RS configuration object

        csirsIndSubs_kTemp = csirsInd(:,1);
        csirsIndSubs_lTemp = csirsInd(:,2);
        % Consider the CSI-RS indices present only in the BWP
        indInBWP = (csirsIndSubs_kTemp >= bwpStart*12 + 1) & csirsIndSubs_kTemp <= (bwpStart + reportConfig.NSizeBWP)*12;
        csirsIndSubs_k = csirsIndSubs_kTemp(indInBWP);
        csirsIndSubs_l = csirsIndSubs_lTemp(indInBWP);

        % Make the CSI-RS subscripts relative to BWP
        csirsIndSubs_k = csirsIndSubs_k - bwpStart*12;
        % Get the PMI and SINR values from the PMI selection function
        [PMISet,PMIInfo] = hDLPMISelect(carrier,csirs,reportConfig,nLayers,H,nVar);

        if (isempty(csirsIndSubs_k) || (nVar == 0) || (all(isnan(PMISet.i1)) && all(isnan(PMISet.i2(:)))))
            if CQISubbandInfo.NumSubbands == 1
                % Convert the numSubbands to 0 to report only the wideband CQI
                % index in case of wideband mode
                numSubbands = 0;
            else
                numSubbands = CQISubbandInfo.NumSubbands;
            end
            % Report CQI and the CQI information structure parameters as NaN
            CQI = NaN(numSubbands+1,numCodewords);
            CQIInfo.SINRPerSubbandPerCW = NaN(numSubbands+1,numCodewords);
            CQIInfo.SINRPerRBPerCW = NaN(reportConfig.NSizeBWP,carrier.SymbolsPerSlot,numCodewords);
            CQIInfo.SubbandCQI = NaN(numSubbands+1,numCodewords);
            return; 
        end

        sinrPerREPMI = PMIInfo.SINRPerREPMI;
        if any(strcmpi(reportConfig.CodebookType,{'Type2','eType2'}))
            SINRperSubband = PMIInfo.SINRPerSubband;
            if strcmpi(reportConfig.CQIMode,'Subband') && strcmpi(reportConfig.PMIMode,'Wideband')
                SINRperSubband = getSubbandSINR(sinrPerREPMI,CQISubbandInfo,csirsIndSubs_k);
            end

            % Get the SINR values corresponding to the PMISet in RB level
            % granularity. These values are not directly used for CQI
            % computation. These are just for information purpose
            SINRsperRBperCW = getSINRperRB(sinrPerREPMI,csirsIndSubs_k,csirsIndSubs_l,reportConfig.NSizeBWP,carrier.SymbolsPerSlot);
        else
            SINRperSubband = NaN(CQISubbandInfo.NumSubbands,nLayers);
            if isfield(reportConfig,'PRGSize') && ~isempty(reportConfig.PRGSize)
                % When PRGSize field is configured as other than empty, the CQI
                % computation is done by choosing one random i2 value from all
                % the i2 values corresponding to the PRGs spanning the subband
                % or the wideband based on the CQI mode, as defined in TS
                % 38.214 Section 5.2.1.4.2
                rng(0); % Set RNG state for repeatability
                randomi2 = zeros(1,CQISubbandInfo.NumSubbands);
                if strcmpi(reportConfig.CQIMode,'Subband')
                    % Map the PRGs to subbands
                    index = 1;
                    thisSubbandSize = CQISubbandInfo.SubbandSizes(1);
                    % Get the starting position of each PRG with respect to the
                    % current subband. It helps to compute the number of PRGs
                    % in the respective subband
                    startPRG = ones(1,CQISubbandInfo.NumSubbands+1);
                    for prgIdx = 1:numel(PMISubbandInfo.SubbandSizes)
                        if (thisSubbandSize - PMISubbandInfo.SubbandSizes(prgIdx) == 0) && (index < CQISubbandInfo.NumSubbands)
                            % Go to the next subband index and replace the
                            % current subband size
                            index = index + 1;
                            thisSubbandSize = CQISubbandInfo.SubbandSizes(index);
                            % Mark the corresponding PRG index as the start of
                            % subband
                            startPRG(index) = prgIdx + 1;
                        else
                            thisSubbandSize = thisSubbandSize - PMISubbandInfo.SubbandSizes(prgIdx);
                        end
                    end
                    % Append the total number of PRGs + 1 value to the
                    % startPRG vector. The value points to the last PRG at the
                    % end of the BWP, to know the number of PRGs in the last
                    % subband
                    startPRG(index+1) = PMISubbandInfo.NumSubbands+1;
                    % Loop over all the subbands and choose an i2 value
                    % randomly from the i2 values corresponding to all the PRGs
                    % spanning each subband
                    for idx = 2:numel(startPRG)
                        i2Set = PMISet.i2(startPRG(idx-1):startPRG(idx)-1);
                        randomi2(idx-1) = i2Set(randi(numel(i2Set)));
                        if ~isnan(randomi2(idx-1))
                            SINRperSubband(idx-1,:) = mean(PMIInfo.SINRPerSubband(startPRG(idx-1):startPRG(idx)-1,:,randomi2(idx-1),PMISet.i1(1),PMISet.i1(2),PMISet.i1(3)),'omitnan');
                        end
                    end
                    SINRsperRECQI = getSINRperRECQI(PMIInfo.SINRPerRE,struct('i1',PMISet.i1,'i2',randomi2),CQISubbandInfo.SubbandSizes,csirsIndSubs_k);
                else
                    % Choose an i2 value randomly from the i2 values other than
                    % NaNs corresponding to all the PRGs in the BWP
                    i2Set = PMISet.i2(~isnan(PMISet.i2));
                    randomi2 = i2Set(randi(numel(i2Set)));
                    SINRperSubband(:,:) = mean(PMIInfo.SINRPerSubband(:,:,randomi2,PMISet.i1(1),PMISet.i1(2),PMISet.i1(3)),'omitnan');
                    SINRsperRECQI = PMIInfo.SINRPerRE(:,:,randomi2,PMISet.i1(1),PMISet.i1(2),PMISet.i1(3));
                end
                % Get the SINR values in RB level granularity, based on the
                % random i2 values selected. These values are not directly used
                % for CQI computation. These are just for information purpose
                SINRsperRBperCW = getSINRperRB(SINRsperRECQI,csirsIndSubs_k,csirsIndSubs_l,reportConfig.NSizeBWP,carrier.SymbolsPerSlot);
            else
                % If PRGSize is not configured, the output from PMI selection
                % function is either in wideband or subband level granularity
                % based on the PMIMode

                % Get the SINR values corresponding to the PMISet in RB level
                % granularity. These values are not directly used for CQI
                % computation. These are just for information purpose
                SINRsperRBperCW = getSINRperRB(sinrPerREPMI,csirsIndSubs_k,csirsIndSubs_l,reportConfig.NSizeBWP,carrier.SymbolsPerSlot);

                % Deduce the SINR values for the CQI computation based on the
                % CQI mode, as the SINRPerSubband field in the PMI information
                % output has the SINR values according to the PMIMode
                if strcmpi(reportConfig.PMIMode,'Wideband')
                    % If PMI mode is 'Wideband', only one i2 value is reported
                    % and the SINR values are obtained for the entire BWP in
                    % the SINRPerSubband field of PMIInfo output. In this case
                    % compute the SINR values corresponding to subband or
                    % wideband based on the CQI mode
                    SINRperSubband = getSubbandSINR(sinrPerREPMI,CQISubbandInfo,csirsIndSubs_k);
                else
                    % If PMI mode is 'Subband', when codebook type is specified
                    % as 'Type1SinglePanel', one i2 value is reported per
                    % subband and when codebook type is specified as
                    % 'Type1MultiPanel', a set of three indices [i20; i21; i22]
                    % are reported per subband. The SINR values are obtained in
                    % subband level granularity from PMI selection function.
                    % Extract the SINR values accordingly
                    for subbandIdx = 1:size(PMISet.i2,2)
                        if ~any(isnan(PMISet.i2(:,subbandIdx)))
                            if strcmpi(reportConfig.CodebookType,'Type1MultiPanel')
                                SINRperSubband(subbandIdx,:) = PMIInfo.SINRPerSubband(subbandIdx,:,PMISet.i2(1,subbandIdx),PMISet.i2(2,subbandIdx),PMISet.i2(3,subbandIdx),PMISet.i1(1),PMISet.i1(2),PMISet.i1(3),PMISet.i1(4),PMISet.i1(5),PMISet.i1(6));
                            else
                                SINRperSubband(subbandIdx,:) = PMIInfo.SINRPerSubband(subbandIdx,:,PMISet.i2(subbandIdx),PMISet.i1(1),PMISet.i1(2),PMISet.i1(3));
                            end
                        end
                    end
                end
            end
        end
        % Get SINR per subband
        SINRperSubbandperCW = zeros(CQISubbandInfo.NumSubbands,numCodewords);
        for subbandIdx = 1:CQISubbandInfo.NumSubbands
            % Get the SINR values per layer and calculate the SINR values
            % corresponding to each codeword
            layerSINRs = squeeze(SINRperSubband(subbandIdx,:));

            if ~any(isnan(layerSINRs))
                codewordSINRs = cellfun(@sum,nrLayerDemap(layerSINRs));
            else
                % If the linear SINR values of the codeword are NaNs, which
                % implies, there are no CSI-RS resources in the current
                % subband. So, the SINR values for the codewords are
                % considered as NaNs for the particular subband
                codewordSINRs = NaN(1,numCodewords);
            end
            SINRperSubbandperCW(subbandIdx,:) = codewordSINRs;
        end

        if size(SINRperSubbandperCW,1) > 1
            % Compute the wideband SINR value as a mean of the subband SINRs,
            % if either CQI or PMI are configured in subband mode
            SINRperSubbandperCW = [mean(SINRperSubbandperCW,1,'omitnan'); SINRperSubbandperCW];
        end
    end

    BLERForAllSubbands = zeros(CQISubbandInfo.NumSubbands,numCodewords);

    %Initialize L2SM for CQISelection calculation
    l2sm = nr5g.internal.L2SM.initialize(carrier);

    if ~inputSINRTable
        % Get CSI reference resource for CQI selection, as defined in TS
        % 38.214 Section 5.2.2.5
        [pdsch,pdschExt] = hCSIReferenceResource(carrier,reportConfig,nLayers);

        % Get CQI, effective SINR and estimated BLER per subband
        SINRperSubbandperCW = zeros(CQISubbandInfo.NumSubbands,numCodewords);
        CQIForAllSubbands = NaN(CQISubbandInfo.NumSubbands,numCodewords);
        subbandStart = 0;
        for subbandIdx = 1:CQISubbandInfo.NumSubbands
            % Subcarrier indices for this subband
            subbandInd = (csirsIndSubs_k>subbandStart*12) & (csirsIndSubs_k<(subbandStart+ CQISubbandInfo.SubbandSizes(subbandIdx))*12+1);
            % Compute CQI, effective SINR and estimated BLER
            [l2sm,CQIForAllSubbands(subbandIdx,:),SINRperSubbandperCW(subbandIdx,:),BLERForAllSubbands(subbandIdx,:)] = ...
                cqiSelect(l2sm,carrier,pdsch,pdschExt.XOverhead,PMIInfo.SINRPerREPMI(subbandInd,:,:),reportConfig.CQITable);
            % Compute the starting position of next subband
            subbandStart = subbandStart + CQISubbandInfo.SubbandSizes(subbandIdx);
        end

        if size(SINRperSubbandperCW,1) > 1
            % Compute the wideband CQI, effective SINR and estimated BLER, if
            % either CQI or PMI are configured in subband mode
            [l2sm,wbCQI,wbEffectiveSINR,wbBLER] = cqiSelect(l2sm,carrier,pdsch,pdschExt.XOverhead,PMIInfo.SINRPerREPMI,reportConfig.CQITable);
            CQIForAllSubbands = [wbCQI; CQIForAllSubbands];
            BLERForAllSubbands = [wbBLER; BLERForAllSubbands];
            SINRperSubbandperCW = [wbEffectiveSINR; SINRperSubbandperCW];
        end
    end

    if inputSINRTable
        % Get the CQI value
        CQIForAllSubbands = arrayfun(@(x)getCQI(x,SINRTable),SINRperSubbandperCW);
    end

    % Compute the subband differential CQI value in case of subband
    % mode
    if strcmpi(reportConfig.CQIMode,'Subband')
        % Map the subband CQI values to their subband differential
        % value as defined in TS 38.214 Table 5.2.2.1-1. According to
        % this table, a subband differential CQI value is reported for
        % each subband based on the offset level, where the offset
        % level = subband CQI index - wideband CQI index
        CQIdiff = CQIForAllSubbands(2:end,:) - CQIForAllSubbands(1,:);

        % If the CQI value in any subband is NaN, consider the
        % corresponding subband differential CQI as NaN. It indicates
        % that there are no CSI-RS resources present in that particular
        % subband
        CQIOffset(isnan(CQIdiff)) = NaN;
        CQIOffset(CQIdiff == 0) = 0;
        CQIOffset(CQIdiff == 1) = 1;
        CQIOffset(CQIdiff >= 2) = 2;
        CQIOffset(CQIdiff <= -1) = 3;

        CQIOffset = reshape(CQIOffset,[],numCodewords);
        % Form an output CQI array to include wideband CQI value
        % followed by subband differential values
        CQI = [CQIForAllSubbands(1,:); CQIOffset];
    else
        % In 'Wideband' CQI mode, report only the wideband CQI index
        CQI = CQIForAllSubbands(1,:);
    end

    % Form the output CQI information structure
    CQIInfo.SINRPerRBPerCW = SINRsperRBperCW;
    CQIInfo.SINRPerSubbandPerCW = SINRperSubbandperCW;
    if strcmpi(reportConfig.CQIMode,'Wideband')
        % Output wideband CQI value, if CQIMode is 'Wideband'
        CQIInfo.SubbandCQI = CQIForAllSubbands(1,:);
        CQIInfo.SINRPerSubbandPerCW = SINRperSubbandperCW(1,:);
        CQIInfo.TransportBLER = BLERForAllSubbands(1,:);
    else
        % Output wideband CQI value followed by subband CQI values, if
        % CQIMode is 'Subband'
        CQIInfo.SubbandCQI = CQIForAllSubbands;
        CQIInfo.TransportBLER = BLERForAllSubbands;
    end
end

function CQI = getCQI(linearSINR,SINRTable)
%   CQI = getCQI(LINEARSINR,SINRTABLE) returns the maximum CQI value that
%   corresponds to 90 percent throughput by considering these inputs:
%
%   LINEARSINR - The SINR value in linear scale for which the CQI value has
%                to be computed
%   SINRTABLE  - The SINR lookup table using which the CQI value is reverse
%                mapped

    % Convert the SINR values to decibels
    SINRatRxdB  = 10*log10(linearSINR);

    % The measured SINR value is compared with the SINRs in the lookup
    % table. The CQI index corresponding to the maximum SINR value from the
    % table, which is less than the measured value is reported by the UE
    cqiTemp = find(SINRTable <= SINRatRxdB,1,'last');
    if isempty(cqiTemp)
        % If there is no CQI value that corresponds to 90 percent
        % throughput, CQI value is chosen as 0
        CQI = 0;
    else
        CQI = cqiTemp;
    end
end

function SINRsperRECQI = getSINRperRECQI(SINRsperRE,PMISet,subbandSizes,csirsIndSubs_k)
%   SINRSPERRECQI = getSINRperRECQI(SINRSPERRE,PMISET,SUBBANDSIZES,CSIRSINDSUBS_K) returns
%   the SINR values corresponding to the PMISet in RE level granularity
%   spanning one slot, by considering these inputs:
%
%   SINRSPERRE   - The SINR values per RE for all PMI indices
%   PMISET       - The PMI value reported
%   SUBBANDSIZES - The array representing size of each subband

    numSubbands = size(PMISet.i2,2);
    % Get SINR values per RE based on the PMI values
    start = 0;
    SINRsperRECQI = NaN(size(SINRsperRE,1),size(SINRsperRE,2));
    for idx = 1:numSubbands
        if ~any(isnan(PMISet.i2(:,idx)))
            subbandInd = (csirsIndSubs_k>start*12) & (csirsIndSubs_k<(start+ subbandSizes(idx))*12+1);
            if numel(PMISet.i1) == 6
               % In this case the codebook type is 'Type1MultiPanel'
               SINRsperRECQI(subbandInd,:) = SINRsperRE(subbandInd,:,PMISet.i2(1,idx),PMISet.i2(2,idx),PMISet.i2(3,idx),PMISet.i1(1),PMISet.i1(2),PMISet.i1(3),PMISet.i1(4),PMISet.i1(5),PMISet.i1(6));
            else
               SINRsperRECQI(subbandInd,:) = SINRsperRE(subbandInd,:,PMISet.i2(idx),PMISet.i1(1),PMISet.i1(2),PMISet.i1(3));
            end
        end
        start = start + subbandSizes(idx);
    end
end

function SINRsperRBperCW = getSINRperRB(SINRsperRECQI,csirsIndSubs_k,csirsIndSubs_l,NSizeBWP,SymbolsPerSlot)
%   SINRSPERRBPERCW = getSINRperRB(SINRSPERRECQI,CSIRSINDSUBS_K,CSIRSINDSUBS_L,NSIZEBWP,SYMBOLSPERSLOT)
%   returns the SINR values corresponding to the PMISet in RB level
%   granularity spanning one slot.

    % Calculate SINR value per RE per each codeword
    nLayers = size(SINRsperRECQI,2);
    numCodewords = ceil(nLayers/4);
    SINRsperREperCW = NaN(size(SINRsperRECQI,1),numCodewords);
    for k = 1:size(SINRsperRECQI,1)
        temp = reshape(SINRsperRECQI(k,:),1,[]);
        if ~all(isnan(temp))
            SINRsperREperCW(k,:) = cellfun(@sum,nrLayerDemap(temp));
        end
    end

    % Calculate the SINR value per RB by averaging the SINR values per
    % RE within RB spanning one slot
    SINRsperRBperCW = NaN(NSizeBWP,SymbolsPerSlot,numCodewords);
    for RBidx = 1:NSizeBWP
        % Consider the mean of SINR values over each RB
        RBSymbolIndices = csirsIndSubs_l((csirsIndSubs_k>=((RBidx-1)*12+1))&(csirsIndSubs_k<=(RBidx*12)));
        uniqueSymbols = unique(RBSymbolIndices);
        for SymIdx = 1:length(uniqueSymbols)
            SCIndInRB = RBSymbolIndices(RBSymbolIndices==uniqueSymbols(SymIdx));
            RBSINRs = SINRsperREperCW(SCIndInRB,:);
            SINRsperRBperCW(RBidx,uniqueSymbols(SymIdx),:) = mean(RBSINRs,1);
        end
    end
end

function SubbandSINRs = getSubbandSINR(SINRsperREPMI,SubbandInfo,csirsIndSubs_k)
%   SUBBANDSINRS = (SINRSPERREPMI,SUBBANDINFO,CSIRSINDSUBS_K) returns
%   the SINR values per subband by averaging the SINR values across all the
%   REs within the subband spanning one slot, corresponding to the reported
%   PMI indices, by considering these inputs:
%
%   SINRSPERREPMI  - SINR values per RE for the reported PMI
%   SUBBANDINFO    - Subband information related structure with these 
%   fields:
%      NumSubbands  - Number of subbands
%      SubbandSizes - Size of each subband

    SubbandSINRs = NaN(SubbandInfo.NumSubbands,size(SINRsperREPMI,2));
    % Consider the starting position of first subband as start of BWP
    subbandStart = 0;
    for SubbandIdx = 1:SubbandInfo.NumSubbands
        subbandInd = (csirsIndSubs_k>subbandStart*12) & (csirsIndSubs_k<(subbandStart+ SubbandInfo.SubbandSizes(SubbandIdx))*12+1);
        sinrTmp = SINRsperREPMI(subbandInd,:,:);
        if ~all(isnan(sinrTmp(:)))
            SubbandSINRs(SubbandIdx,:) = mean(sinrTmp,1);
        end
        subbandStart = subbandStart+ SubbandInfo.SubbandSizes(SubbandIdx);
    end
end

function [reportConfig,SINRTable,nVar] = validateInputs(carrier,reportConfig,nLayers,H,nVar,SINRTable,numCSIRSPorts,csirsInd,isCSIRSObjSyntax)
%   [REPORTCONFIG,SINRTABLE,NVAR] = validateInputs(CARRIER,REPORTCONFIG,NLAYERS,H,NVAR,SINRTABLE,NUMCSIRSPORTS,CSIRSIND,ISCSIRSOBJSYNTAX)
%   validates the inputs arguments and returns the validated CSI report
%   configuration structure REPORTCONFIG along with the SINR lookup table
%   SINRTABLE for SINR to CQI mapping, and the noise variance NVAR.

    fcnName = 'hCQISelect';
    % Validate 'reportConfig'
    % Validate 'NSizeBWP'
    if ~isfield(reportConfig,'NSizeBWP')
        error('nr5g:hCQISelect:NSizeBWPMissing','NSizeBWP field is mandatory.');
    end
    nSizeBWP = reportConfig.NSizeBWP;
    if ~(isnumeric(nSizeBWP) && isempty(nSizeBWP))
        validateattributes(nSizeBWP,{'double','single'},{'scalar','integer','positive','<=',275},fcnName,'the size of BWP');
    else
        nSizeBWP = carrier.NSizeGrid;
    end
    % Validate 'NStartBWP'
    if ~isfield(reportConfig,'NStartBWP')
        error('nr5g:hCQISelect:NStartBWPMissing','NStartBWP field is mandatory.');
    end
    nStartBWP = reportConfig.NStartBWP;
    if ~(isnumeric(nStartBWP) && isempty(nStartBWP))
        validateattributes(nStartBWP,{'double','single'},{'scalar','integer','nonnegative','<=',2473},fcnName,'the start of BWP');
    else
        nStartBWP = carrier.NStartGrid;
    end
    if nStartBWP < carrier.NStartGrid
        error('nr5g:hCQISelect:InvalidNStartBWP',...
            ['The starting resource block of BWP ('...
            num2str(nStartBWP) ') must be greater than '...
            'or equal to the starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ').']);
    end
    % BWP must lie within the limits of carrier
    if (nSizeBWP + nStartBWP)>(carrier.NStartGrid + carrier.NSizeGrid)
        error('nr5g:hCQISelect:InvalidBWPLimits',['The sum of starting resource '...
            'block of BWP (' num2str(nStartBWP) ') and the size of BWP ('...
            num2str(nSizeBWP) ') must be less than or equal to '...
            'the sum of starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ') and size of the carrier ('...
            num2str(carrier.NSizeGrid) ').']);
    end
    reportConfig.NStartBWP = nStartBWP;
    reportConfig.NSizeBWP = nSizeBWP;

    % Validate 'CQITable'
    if isfield(reportConfig,'CQITable')
        reportConfig.CQITable = validatestring(reportConfig.CQITable,{'table1','table2','table3'},fcnName,'CQITable field');
    else
        reportConfig.CQITable = 'table1';
    end

    % Check for the presence of 'CodebookType' field
    if isfield(reportConfig,'CodebookType')
        reportConfig.CodebookType = validatestring(reportConfig.CodebookType,{'Type1SinglePanel','Type1MultiPanel','Type2','eType2'},fcnName,'CodebookType field');
    else
        reportConfig.CodebookType = 'Type1SinglePanel';
    end

    % Check if CQI Mode is specified. Otherwise, by default, consider
    % 'Wideband' mode
    if isfield(reportConfig,'CQIMode')  
        reportConfig.CQIMode =  validatestring(reportConfig.CQIMode,{'Wideband','Subband'},...
            fcnName,'CQIMode field');
    else
        reportConfig.CQIMode = 'Wideband';
    end
    % Check if PMI Mode is specified. Otherwise, by default, consider
    % 'Wideband' mode
    if isfield(reportConfig,'PMIMode')
        reportConfig.PMIMode = validatestring(reportConfig.PMIMode,{'Wideband','Subband'},...
            fcnName,'PMIMode field');
    else
        reportConfig.PMIMode = 'Wideband';
    end

    % Validate 'PRGSize'
    if isfield(reportConfig,'PRGSize') && strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        if ~(isnumeric(reportConfig.PRGSize) && isempty(reportConfig.PRGSize))
            validateattributes(reportConfig.PRGSize,{'double','single'},...
                {'real','scalar'},fcnName,'PRGSize field');
        end
        if ~(isempty(reportConfig.PRGSize) || any(reportConfig.PRGSize == [2 4]))
            error('nr5g:hCQISelect:InvalidPRGSize',...
                ['PRGSize value (' num2str(reportConfig.PRGSize) ') must be [], 2, or 4.']);
        end
        reportConfig.PRGSize = reportConfig.PRGSize;
    else
        reportConfig.PRGSize = [];
    end

    % Validate 'SubbandSize'
    NSBPRB = [];
    if strcmpi(reportConfig.CQIMode,'Subband') ||...
            (isempty(reportConfig.PRGSize) && strcmpi(reportConfig.PMIMode,'Subband'))
        if nSizeBWP >= 24
            if isCSIRSObjSyntax
                fieldName = 'SubbandSize';
            else
                fieldName = 'NSBPRB';
            end
            if ~isfield(reportConfig,'SubbandSize')
                error('nr5g:hCQISelect:SubbandSizeMissing',...
                    ['For the subband mode, ' fieldName ' field is '...
                    'mandatory when the size of BWP is more than 24 PRBs.']);
            else
                validateattributes(reportConfig.SubbandSize,{'double','single'},...
                    {'real','scalar'},fcnName,fieldName);
                NSBPRB = reportConfig.SubbandSize;
            end

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
                error('nr5g:hCQISelect:InvalidSubbandSize',['For the configured BWP size (' num2str(nSizeBWP) ...
                    '), subband size (' num2str(NSBPRB) ') must be ' num2str(validNSBPRBValues(1)) ...
                    ' or ' num2str(validNSBPRBValues(2)) '.']);
            end
        end
    end
    reportConfig.SubbandSize = NSBPRB;

    % Validate 'nLayers'
    if strcmpi(reportConfig.CodebookType,'Type2')
        codebookType = 'Type II';
        maxNLayers = 2;
    elseif strcmpi(reportConfig.CodebookType,'eType2')
        codebookType = 'Enhanced Type II';
        maxNLayers = 4;
    elseif strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        codebookType = 'Type I Single-Panel';
        maxNLayers = 8;
    else
        codebookType = 'Type I Multi-Panel';
        maxNLayers = 4;
    end
    validateattributes(nLayers,{'numeric'},{'scalar','integer','positive','<=',maxNLayers},fcnName,['NLAYERS(' num2str(nLayers) ') for ' codebookType ' codebooks']);

    % Validate the channel estimate and its dimensions
    validateattributes(numel(size(H)),{'double'},{'>=',2,'<=',4},fcnName,'number of dimensions of H');
    if ~isempty(csirsInd)
        nRxAnts = size(H,3);
        K = carrier.NSizeGrid*12;
        L = carrier.SymbolsPerSlot;
        if ~isCSIRSObjSyntax
            thirdDim = 1;
        else
            thirdDim = NaN;
        end
        validateattributes(H,{class(H)},{'size',[K L thirdDim numCSIRSPorts]},fcnName,'H');
        
        % Validate 'nLayers'
        maxNLayers = min(nRxAnts,numCSIRSPorts);
        if nLayers > maxNLayers
            error('nr5g:hCQISelect:InvalidNumLayers',...
                ['The given antenna configuration (' ...
                num2str(numCSIRSPorts) 'x' num2str(nRxAnts)...
                ') supports only up to (' num2str(maxNLayers) ') layers.']);
        end
    end

    % Validate 'nVar'
    validateattributes(nVar,{'double','single'},{'scalar','real','nonnegative','finite'},fcnName,'NVAR');
    % Clip 'nVar' to a small noise variance to avoid +/-Inf outputs
    if nVar < 1e-10
        nVar = 1e-10;
    end

    % Validate 'SINRTable'
    if ~isempty(SINRTable)
        if isCSIRSObjSyntax
            syntaxString = 'SINRTable';
        else
            syntaxString = 'SINR90pc field';
        end
        validateattributes(SINRTable,{'double','single'},{'vector','real','numel',15},fcnName,syntaxString);
    end

end

function [reportConfig,nLayers,H,nVar,SINRTable,isCSIRSObjSyntax,nTxAnts,csirsInd,csirs,inputSINRTable] = parseInputs(carrier,varargin)
%   [REPORTCONFIG,NLAYERS,H,NVAR,SINRTABLE,ISCSIRSOBJSYNTAX,NTXANTS,CSIRSIND,CSIRS] = parseInputs(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H,NVAR,SINRTABLE) 
%   returns the parsed arguments and other required parameters for the
%   syntax with CSI-RS configuration object by considering these inputs:
%   CARRIER      - Carrier configuration object
%   CSIRS        - CSI-RS configuration object
%   REPORTCONFIG - Structure of CSI reporting configuration
%   NLAYERS      - Number of transmission layers
%   H            - Estimated channel information 
%   NVAR         - Estimated noise variance
%   SINRTABLE    - SINR lookup table for SINR to CQI mapping
%
%   [REPORTCONFIG,NLAYERS,H,NVAR,SINRTABLE,ISCSIRSOBJSYNTAX,NTXANTS,CSIRSIND,CSIRS] = parseInputs(CARRIER,BWP,CQICONFIG,CSIRSIND,H,NVAR) 
%   returns the parsed arguments and other required parameters for the
%   syntax with CSI-RS indices by considering these inputs:
%   CARRIER      - Carrier configuration object
%   BWP          - Structure of BWP dimensions
%   CQICONFIG    - Structure of CQI reporting configuration
%   CSIRSIND     - CSI-RS indices
%   H            - Estimated channel information
%   NVAR         - Estimated noise variance

    % Validate the carrier configuration object
    validateattributes(carrier,{'nrCarrierConfig'},{'scalar'},'hCQISelect','CARRIER');
    variableInputArgs = varargin{1};
    if isstruct(variableInputArgs{1})
        % If the first variable argument is a structure, the syntax with
        % CSI-RS indices input is considered. This syntax supports CQI
        % computation only for SISO case. Move the required set of
        % parameters that can adapt into the syntax with CSI-RS
        % configuration object and bind them accordingly, in order to
        % enable easy validation

        % Extract bwp from the first variable input argument
        bwp = variableInputArgs{1};

        % Check if the size and start of BWP fields are present in the bwp
        % structure.
        if ~isfield(bwp,'NSizeBWP')
            error('nr5g:hCQISelect:NSizeBWPMissing','NSizeBWP field is mandatory.');
        end
        if ~isfield(bwp,'NStartBWP')
            error('nr5g:hCQISelect:NStartBWPMissing','NStartBWP field is mandatory.');
        end

        % Extract the CQI configuration related parameter, from the second
        % variable input argument
        reportConfig = variableInputArgs{2};
        % Bind the BWP dimensions into the reportConfig structure
        reportConfig.NStartBWP = bwp.NStartBWP;
        reportConfig.NSizeBWP = bwp.NSizeBWP;

        % Extract the CSI-RS indices from the third variable input argument
        csirsInd = variableInputArgs{3};
        % Validate CSI-RS indices
        validateattributes(csirsInd,{'numeric'},{'positive','integer'},'hCQISelect','CSIRSIND');

        % Extract the channel estimation matrix from fourth variable
        % argument
        H = variableInputArgs{4};

        % Extract the noise variance from fifth variable input argument.
        % For this syntax, the noise variance is a mandatory input. So
        % default value is not considered here
        nVar = variableInputArgs{5};

        % Consider the number of transmission layers as 1 for SISO case
        nLayers = 1;

        % Extract the subband size value NSBPRB, if present, and store it
        % as SubbandSize field (as in the syntax with CSI-RS configuration
        % object) in reportConfig structure
        if isfield(reportConfig,'NSBPRB')
            reportConfig.SubbandSize = reportConfig.NSBPRB;
        end

        % Extract the SINR lookup table SINR90pc, if present, and store it
        % as SINRTable
        if isfield(reportConfig,'SINR90pc')
            SINRTable = reportConfig.SINR90pc;
        else
            % If SINR lookup table is not configured, consider SINRTable as
            % empty
            SINRTable = [];
        end

        % Consider the number of transmit antennas as 1 for SISO case
        nTxAnts = 1;
        % Consider a variable to denote if this syntax considers CSI-RS
        % configuration object
        isCSIRSObjSyntax = false;

        % In case of the syntax with CSI-RS indices as an input, return the
        % CSI-RS configuration object related parameter as empty
        csirs = [];
    elseif isa(variableInputArgs{1},'nrCSIRSConfig')
        % If the first variable input argument is a CSI-RS configuration
        % object, consider the input arguments according to the syntax with
        % CSI-RS configuration object as an input

        % Extract the CSI-RS configuration object as csirs from the first
        % variable input argument
        csirs = variableInputArgs{1};

        % Validate the CSI-RS resources used for CQI computation. All the
        % CSI-RS resources used for the CQI computation must have same CDM
        % lengths and same number of ports according to TS 38.214 Section
        % 5.2.2.3.1
        validateattributes(csirs,{'nrCSIRSConfig'},{'scalar'},'hCQISelect','CSIRS');
        if ~isscalar(unique(csirs.NumCSIRSPorts))
            error('nr5g:hCQISelect:InvalidCSIRSPorts','All the CSI-RS resources must be configured to have same number of CSI-RS ports.');
        else
            % If all the CSI-RS resources have the same number of CSI-RS
            % ports, get the value as number of transmit antennas
            nTxAnts = unique(csirs.NumCSIRSPorts);
        end

        if ~iscell(csirs.CDMType)
            cdmType = {csirs.CDMType};
        else
            cdmType = csirs.CDMType;
        end
        % Check if all the CSI-RS resources are configured to have same
        % CDM lengths
        if ~all(strcmpi(cdmType,cdmType{1}))
            error('nr5g:hCQISelect:InvalidCSIRSCDMTypes','All the CSI-RS resources must be configured to have same CDM lengths.');
        end

        % Ignore zero-power (ZP) CSI-RS resources, as they are not used for
        % CSI estimation
        if ~iscell(csirs.CSIRSType)
            csirs.CSIRSType = {csirs.CSIRSType};
        end
        numZPCSIRSRes = sum(strcmpi(csirs.CSIRSType,'zp'));
        % Calculate the CSI-RS indices
        tempInd = nrCSIRSIndices(carrier,csirs,"IndexStyle","subscript","OutputResourceFormat","cell");
        tempInd = tempInd(numZPCSIRSRes+1:end)';
        
        % Extract the NZP-CSI-RS indices corresponding to first port
        for nzpResIdx = 1:numel(tempInd)
            nzpInd = tempInd{nzpResIdx};
            tempInd{nzpResIdx} = nzpInd(nzpInd(:,3) == 1,:);
        end
        % Extract the indices corresponding to the lowest RE of each CSI-RS CDM
        % group. This improves the computational speed by limiting the number
        % of CSI-RS REs
        if ~strcmpi(cdmType{1},'noCDM')
            for resIdx = 1:numel(tempInd)
                totIndices = size(tempInd{resIdx},1);
                if strcmpi(cdmType{1},'FD-CDM2')
                    indicesPerSym = totIndices;
                elseif strcmpi(cdmType{1},'CDM4')
                    indicesPerSym = totIndices/2;
                elseif strcmpi(cdmType{1},'CDM8')
                    indicesPerSym = totIndices/4;
                end
                tempIndInOneSymbol = tempInd{resIdx}(1:indicesPerSym,:);
                tempInd{resIdx} = tempIndInOneSymbol(1:2:end,:);
            end
        end
        csirsInd = zeros(0,3);
        if ~isempty(tempInd)
            csirsInd = cell2mat(tempInd);
        end

        % Extract the CSI reporting related configuration from second
        % variable input argument
        reportConfig = variableInputArgs{2};

        % Extract the number of transmission layers value as nLayers from
        % the third variable input argument
        nLayers = variableInputArgs{3};

        % Extract the channel estimation matrix from the fourth variable
        % input argument
        H = variableInputArgs{4};

        % Get the number of variable input arguments
        numVarInputArgs = length(variableInputArgs);
        % Extract the noise variance and SINR lookup table
        if numVarInputArgs == 4
            nVar = 1e-10;
            SINRTable = [];
        elseif numVarInputArgs == 5
            nVar = variableInputArgs{5};
            SINRTable = [];
        elseif numVarInputArgs == 6
            nVar = variableInputArgs{5};
            SINRTable = variableInputArgs{6};
        end

        % Consider a variable to denote if this syntax considers CSI-RS
        % configuration object
        isCSIRSObjSyntax = true;
    else
        error('nr5g:hCQISelect:InvalidInputsToTheHelper','The second input argument can be either a structure or a CSI-RS configuration object.');
    end

    inputSINRTable = ~isempty(SINRTable);
end

function [cqiSubbandInfo,pmiSubbandInfo] = getDownlinkCSISubbandInfo(reportConfig)
%   [CQISUBBANDINFO,PMISUBBANDINFO] = getDownlinkCSISubbandInfo(REPORTCONFIG)
%   returns the CQI subband related information CQISUBBANDINFO and PMI
%   subband or precoding resource block group (PRG) related information
%   PMISUBBANDINFO, by considering CSI reporting configuration structure
%   REPORTCONFIG.

    % Validate 'SubbandSize'
    NSBPRB = reportConfig.SubbandSize;
    reportConfig.CQISubbandSize = NSBPRB;
    reportConfig.PMISubbandSize = NSBPRB;

    % If PRGSize is present, consider the subband size as PRG size
    if ~isempty(reportConfig.PRGSize)
        reportConfig.PMIMode = 'Subband';
        reportConfig.PMISubbandSize = reportConfig.PRGSize;
        reportConfig.ignoreBWPSize = true; % To ignore the BWP size for the validation of PRG size
    else
        reportConfig.ignoreBWPSize = false; % To consider the BWP size for the validation of subband size
    end

    % Get the subband information for CQI and PMI reporting
    cqiSubbandInfo = getSubbandInfo(reportConfig.CQIMode,reportConfig.NStartBWP,reportConfig.NSizeBWP,reportConfig.CQISubbandSize,false);
    pmiSubbandInfo = getSubbandInfo(reportConfig.PMIMode,reportConfig.NStartBWP,reportConfig.NSizeBWP,reportConfig.PMISubbandSize,reportConfig.ignoreBWPSize);
end

function info = getSubbandInfo(reportingMode,nStartBWP,nSizeBWP,NSBPRB,ignoreBWPSize)
%   INFO = getSubbandInfo(REPORTINGMODE,NSTARTBWP,NSIZEBWP,NSBPRB,IGNOREBWPSIZE)
%   returns the CSI subband information.

    % Get the subband information
    if strcmpi(reportingMode,'Wideband') || (~ignoreBWPSize && nSizeBWP < 24)
        % According to TS 38.214 Table 5.2.1.4-2, if the size of BWP is
        % less than 24 PRBs, the division of BWP into subbands is not
        % applicable. In this case, the number of subbands is considered as
        % 1 and the subband size is considered as the size of BWP
        numSubbands = 1;
        NSBPRB = nSizeBWP;
        subbandSizes = NSBPRB;
    else
        % Calculate the size of first subband
        firstSubbandSize = NSBPRB - mod(nStartBWP,NSBPRB);

        % Calculate the size of last subband
        if mod(nStartBWP + nSizeBWP,NSBPRB) ~= 0
            lastSubbandSize = mod(nStartBWP + nSizeBWP,NSBPRB);
        else
            lastSubbandSize = NSBPRB;
        end

        % Calculate the number of subbands
        numSubbands = (nSizeBWP - (firstSubbandSize + lastSubbandSize))/NSBPRB + 2;

        % Form a vector with each element representing the size of a subband
        subbandSizes = NSBPRB*ones(1,numSubbands);
        subbandSizes(1) = firstSubbandSize;
        subbandSizes(end) = lastSubbandSize;
    end
    % Place the number of subbands and subband sizes in the output
    % structure
    info.NumSubbands = numSubbands;
    info.SubbandSizes = subbandSizes;
end

% Create a PDSCH configuration for the CSI reference resource, as defined
% in TS 38.214 Section 5.2.2.5
function [pdsch,pdschExt] = hCSIReferenceResource(carrier,reportConfig,numLayers)

    pdsch = nrPDSCHConfig;
    pdsch.NStartBWP = reportConfig.NStartBWP;
    pdsch.NSizeBWP = reportConfig.NSizeBWP;
    pdsch.PRBSet = 0:reportConfig.NSizeBWP-1;
    pdsch.SymbolAllocation = [2 carrier.SymbolsPerSlot-2];
    pdsch.ReservedRE = [];
    pdsch.ReservedPRB = {};
    pdsch.NumLayers = numLayers;
    pdsch.DMRS.NumCDMGroupsWithoutData = 3;

    pdschExt = struct();
    pdschExt.PRGBundleSize = 2;
    pdschExt.RVSeq = 0;
    pdschExt.XOverhead = 0;

end

function [l2sm,cqiIndex,effectiveSINR,transportBLER] = cqiSelect(l2sm,carrier,pdsch,xOverhead,SINRs,cqiTableName)

    % Initialize outputs
    ncw = pdsch.NumCodewords;
    cqiIndex = NaN(1,ncw);
    effectiveSINR = NaN(1,ncw);
    transportBLER = NaN(1,ncw);

    % SINR per layer without NaN
    SINRs = reshape(SINRs,[],pdsch.NumLayers);
    SINRs = 10*log10(SINRs+eps(SINRs));
    nonnan = ~any(isnan(SINRs),2);
    if ~any(nonnan,'all')
        return;
    end
    SINRs = SINRs(nonnan,:);

    % Get modulation orders and target code rates from CQI table
    cqiTable = nr5g.internal.nrCQITables(cqiTableName);
    cqiTable = cqiTable(:,2:3);

    % Use different BLER thresholds for different CQI tables
    % TS 38.214 Section 5.2.2.1
    if strcmpi(cqiTableName,'Table3')
        blerThreshold = 0.00001;
    else
        blerThreshold = 0.1;
    end
    
    [l2sm,cqiIndex,cqiInfo] = nr5g.internal.L2SM.cqiSelect(l2sm,carrier,pdsch,xOverhead,SINRs,cqiTable,blerThreshold);
    effectiveSINR = db2pow(cqiInfo.EffectiveSINR);
    transportBLER = cqiInfo.TransportBLER;
end