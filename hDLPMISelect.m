function [PMISet,info] = hDLPMISelect(carrier,csirs,reportConfig,nLayers,H,varargin)
%hDLPMISelect PDSCH precoding matrix indicator calculation
%   [PMISET,INFO] = hDLPMISelect(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H)
%   returns the precoding matrix indicator (PMI) values, as defined in
%   TS 38.214 Section 5.2.2.2, for the specified carrier configuration
%   CARRIER, CSI-RS configuration CSIRS, channel state information (CSI)
%   reporting configuration REPORTCONFIG, number of transmission layers
%   NLAYERS, and estimated channel information H.
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
%   PRGSize         - Optional. Precoding resource block group (PRG) size
%                     for CQI calculation, provided by the higher-layer
%                     parameter pdsch-BundleSizeForCSI. This field is
%                     applicable when the PMI reporting is needed for the
%                     CSI report quantity cri-RI-i1-CQI, as defined in
%                     TS 38.214 Section 5.2.1.4.2. This report quantity
%                     expects only the i1 set of PMI to be reported as part
%                     of CSI parameters and PMI mode is expected to be
%                     'Wideband'. But, for the computation of the CQI in
%                     this report quantity, PMI i2 values are needed for
%                     each PRG. Hence, the PMI output, when this field is
%                     configured, is given as a set of i2 values, one for
%                     each PRG of the specified size. It must be a scalar
%                     and it must be one of {2, 4}. Empty ([]) is also
%                     supported to represent that this field is not
%                     configured by higher layers. If it is present and not
%                     configured as empty, irrespective of the PMIMode,
%                     PRGSize is considered for the number of subbands
%                     calculation instead of SubbandSize and the function
%                     reports PMI for each PRG. This field is applicable
%                     only when the CodebookType is specified as
%                     'Type1SinglePanel'. The default value is []
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
%                     'Type1SinglePanel'. The default value is empty ([]),
%                     which means there is no i2 restriction
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
%   For the CodebookSubsetRestriction,
%   - When CodebookType field is specified as 'Type1SinglePanel' or
%   'Type1MultiPanel', the element N2*O2*l+m+1 (1-based) is associated with
%   the precoding matrices based on vlm (l = 0...N1*O1-1, m = N2*O2-1). If
%   the associated binary value is zero, then all the precoding matrices
%   based on vlm are restricted.
%   - When CodebookType field is specified as 'Type1SinglePanel', only if
%   the number of transmission layers is one of {3, 4} and the number of
%   CSI-RS ports is greater than or equal to 16, the elements
%   {mod(N2*O2*(2*l-1)+m,N1*O1*N2*O2)+1, N2*O2*(2*l)+m+1,
%   N2*O2*(2*l+1)+m+1} (1-based) are each associated with all the precoding
%   matrices based on vbarlm (l = 0....(N1*O1/2)-1, m = 0....N2*O2), as
%   defined in TS 38.214 Section 5.2.2.2.1. If one or more of the
%   associated binary values is zero, then all the precoding matrices based
%   on vbarlm are restricted.
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
%   PMISET is an output structure with these fields:
%   i1 - Indicates wideband PMI (1-based).
%           - It is a three-element vector in the form of [i11 i12 i13],
%             when CodebookType is specified as 'Type1SinglePanel'. Note
%             that i13 is not applicable when the number of transmission
%             layers is one of {1, 5, 6, 7, 8}. In that case, function
%             returns the value of i13 as 1
%           - It is a six-element vector in the form of
%             [i11 i12 i13 i141 i142 i143] when CodebookType is specified
%             as 'Type1MultiPanel'. Note that when CodebookMode is 1 and
%             number of antenna panels is 2, i142 and i143 are not
%             applicable and when CodebookMode is 2, i143 is not
%             applicable. In both the codebook modes, i13 value is not
%             applicable when the number of transmission layers is 1. In
%             these cases, the function returns the respective values as 1
%           - It is an array with the elements in the following order
%             [q1 q2 i12 i131 AmplitudeSet1 i132 AmplitudeSet2] when
%             CodebookType is specified as 'Type2'. q1 and q2 represents
%             the oversampled beam indices in horizontal and vertical
%             direction. i12 represents the orthogonal beam group index.
%             AmplitudeSet1 and AmplitudeSet2 are each vectors with the
%             amplitude values corresponding to the number of beams for
%             each polarization on each layer respectively. i131 and i132
%             values represent the strongest beam indices for each layer
%             respectively. The elements are placed in this order according
%             to TS 38.214 Section 5.2.2.2.3
%           - When CodebookType is specified as 'eType2', it is an array
%             with the elements in the following order
%             [i11 i12 i15 i161 i171 i181] for 1 layer
%             [i11 i12 i15 i161 i171 i181 i162 i172 i182] for 2 layers
%             [i11 i12 i15 i161 i171 i181 i162 i172 i182 i163 i173 i183] for 3 layers
%             [i11 i12 i15 i161 i171 i181 i162 i172 i182 i163 i173 i183 i164 i174 i184] for 4 layers
%             Where,
%             i11  - A two-element vector in the form of [q1 q2],
%             representing the oversampled beam indices in horizontal and
%             vertical direction
%             i12  - Orthogonal beam group number
%             i15  - Index of reported Minit value and it is same for all
%             the layers
%             i16l - Integer representing the subband indices n3, which are
%             needed to form the DFT basis for frequency-domain
%             compression, as defined in TS 38.214 Section 5.2.2.2.5. It is
%             reported for each layer separately
%             i17l - Bitmap to identify the reported differential amplitude
%             and phase coefficients for each layer. It is of size
%             1-by-2*numBeams*Mv. numBeams represents the number of beams
%             and Mv represents the number of DFT vectors used for
%             frequency-domain compression
%             i18l - Strongest coefficient on each layer. It is in the
%             range of {0...2*numBeams-1}
%   i2 - Indicates subband PMI.
%           - For 'Type1SinglePanel' codebook type (1-based)
%                - When PMIMode is specified as 'wideband', it is a scalar
%                  representing one i2 indication for the entire band
%                - When PMIMode is specified as 'subband' or when PRGSize
%                  is configured as other than empty ([]), one subband
%                  indication i2 is reported for each subband or PRG,
%                  respectively. Length of the i2 vector in the latter case
%                  equals to the number of subbands or PRGs
%           - For 'Type1MultiPanel' codebook type (1-based)
%                - When PMIMode is specified as 'wideband', it is a
%                  three-element column vector in the form of
%                  [i20; i21; i22] representing one i2 set for the entire
%                  band
%                - When PMIMode is configured as 'subband', it is a matrix
%                  of size 3-by-numSubbands, where numSubbands represents
%                  the number of subbands. In subband PMIMode, each column
%                  represents an indices set [i20; i21; i22] for each
%                  subband and each row consists of an array of elements of
%                  length numSubbands. Note that when CodebookMode is
%                  specified as 1, i21 and i22 are not applicable. In that
%                  case i2 is considered as i20 (first row), and i21 and
%                  i22 are given as ones
%           - For 'Type2' codebooks it is an array with the elements in
%             the following order
%                -  When SubbandAmplitude is true,
%                   For single layer:
%                   the index set for each subband is in the form of
%                   [i211 i221] with the size
%                   2*reportConfig.NumberOfBeams-by-2-by-numSubbands.
%                   For two layers:
%                   the index set for each subband is in the form of
%                   [i211 i221 i212 i222] with the size
%                   2*reportConfig.NumberOfBeams-by-4-by-numSubbands. i211
%                   and i212 are column vectors corresponding to the
%                   co-phasing factors for both the polarizations for each
%                   layer and the values are in the range
%                   of 0:PhaseAlphabetSize-1. i221 and i222 are column
%                   vectors corresponding to subband amplitudes (1-based)
%                   for both the polarizations for each layer, as defined
%                   in TS 38.214 Table 5.2.2.2.3-3
%                -  When SubbandAmplitude is false,
%                   For single layer:
%                   the index set for each subband is in the form of
%                   i211 with the size
%                   2*reportConfig.NumberOfBeams-by-1-by-numSubbands.
%                   For two layers:
%                   the index set for each subband is in the form of
%                   [i211 i212] with the size
%                   2*reportConfig.NumberOfBeams-by-2-by-numSubbands. i211
%                   and i212 are column vectors corresponding to the
%                   co-phasing factors for both the polarizations for each
%                   layer and the values are in the range
%                   of 0:PhaseAlphabetSize-1
%           - For 'eType2' codebooks it is an array with the elements in
%             the following order
%             [i231 i241 i251] for single layer
%             [i231 i241 i251 i232 i242 i252] for 2 layers
%             [i231 i241 i251 i232 i242 i252 i233 i243 i253] for 3 layers
%             [i231 i241 i251 i232 i242 i252 i233 i243 i253 i234 i244 i254] for 4 layers
%             Where,
%             i23l - Reference amplitudes (1-based) of both the
%             polarizations for each layer. For each layer, it is a
%             two-element vector in the form of [kl0(1) kl1(2)]
%             i24l - Represents the differential amplitudes (1-based). It
%             is a vector of size 1-by-2*numBeams*Mv for each layer
%             i25l - Represents phase coefficients. It is a vector of size
%             1-by-2*numBeams*Mv for each layer and the values are in the
%             range of 0:15
%
%   Note that when the number of CSI-RS ports is 2, the applicable codebook
%   type is 'Type1SinglePanel'. In this case, the precoding matrix is
%   obtained by a single index (i2 field here) based on TS 38.214 Table
%   5.2.2.2.1-1. The function returns the i1 as [1 1 1] to support same
%   indexing for all INFO fields according to 'Type1SinglePanel' codebook
%   type.  When the number of CSI-RS ports is 1, all the values of i1 and
%   i2 fields are returned as ones, considering the dimensions of type I
%   single-panel codebook index set.
%
%   INFO is an output structure with these fields:
%   SINRPerRE      - It represents the linear signal to noise plus
%                    interference ratio (SINR) values for the CSI-RS
%                    locations within the BWP for all the layers and all
%                    the precoding matrices. When CodebookType is specified
%                    as 'Type1SinglePanel', it is a multidimensional array
%                    of size
%                       - csirsIndLen-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%                         when the number of CSI-RS ports is greater than 2
%                       - csirsIndLen-by-nLayers-by-i2Length when the number of
%                         CSI-RS ports is 2
%                       - csirsIndLen when the number of CSI-RS ports is 1
%                    csirsIndLen is the number of CSI-RS RE locations
%                    within the BWP used for SINR calculation, i2Length is
%                    the maximum number of possible i2 values and
%                    i11Length, i12Length, i13Length are the maximum number
%                    of possible i11, i12, and i13 values for the given
%                    report configuration respectively. When CodebookType
%                    is specified as 'Type1MultiPanel', it is a
%                    multidimensional array of size
%                    csirsIndLen-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
%                    i20Length, i21Length, i22Length, i141Length,
%                    i142Length and i143Length are the maximum number of
%                    possible i20, i21, i22, i141, i142, and i143 values
%                    for the given configuration respectively. When
%                    CodebookType is specified as 'Type2' or 'eType2', this
%                    field is not applicable and returned as []
%   SINRPerREPMI   - It represents the linear SINR values for the CSI-RS 
%                    locations within the BWP for all the layers for the
%                    reported precoding matrix. It is of size
%                    csirsIndLen-by-nLayers
%   SINRPerSubband - It represents the linear SINR values in each subband
%                    for all the layers. SINR value in each subband is
%                    formed by averaging SINRPerRE estimates across each
%                    subband (i.e. in the appropriate region of the N
%                    dimension and across the L dimension).
%                    When CodebookType is specified as 'Type1SinglePanel',
%                    it is a multidimensional array of size
%                       - numSubbands-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%                         when the number of CSI-RS ports is greater than 2
%                       - numSubbands-by-nLayers-by-i2Length when the
%                         number of CSI-RS ports is 2
%                       - numSubbands-by-1 when the number of CSI-RS ports
%                         is 1
%                    When CodebookType is specified as 'Type1MultiPanel',
%                    it is a multidimensional array of size
%                       - numSubbands-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
%                    When CodebookType is specified as 'Type2' or 'eType2',
%                    this field is of dimensions numSubbands-by-nLayers
%   Codebook       - Multidimensional array containing precoding matrices
%                    based on the CSI reporting configuration.
%                    When CodebookType is specified as 'Type1SinglePanel',
%                    it is a multidimensional array of size
%                       - Pcsirs-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%                         when the number of CSI-RS ports is greater than 2
%                       - 2-by-nLayers-by-i2Length when the number of
%                         CSI-RS ports is 2
%                       - 1-by-1 with the value 1 when the number of CSI-RS
%                         ports is 1
%                    When CodebookType is specified as 'Type1MultiPanel',
%                    it is a multidimensional array of size
%                       - Pcsirs-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
%                    When CodebookType is specified as 'Type2' or 'eType2',
%                    it is reported as []
%                    Note that the restricted precoding matrices as per the
%                    report configuration are returned as all zeros, for
%                    type I codebooks
%   W              - Precoding matrix that corresponds to the reported
%                    PMI in each subband. It is a matrix of size
%                    Pcsirs-by-nLayers-by-numSubbands. For wideband case,
%                    numSubbands will be 1
%   CSIRSIndices   - Matrix corresponding to CSI-RS RE indices (1-based) 
%                    where SINR is computed. Each element in First column
%                    corresponds to subcarrier index, second column
%                    corresponds to an OFDM symbol index and third column
%                    corresponds to port index. To improve computation
%                    speed, fewer CSI-RS REs are considered without losing
%                    the much accuracy in SINR values
%
%   [PMISET,INFO] = hDLPMISelect(...,NVAR) specifies the estimated noise
%   variance at the receiver NVAR as a nonnegative scalar. By default, the
%   value of nVar is considered as 1e-10, if it is not given as input.
%
%   Note that i1 and i2 fields of PMISET and SINRPerRE and SINRPerSubband
%   fields of INFO are returned as array of NaNs for these cases:
%   - When CSI-RS is not present in the operating slot or in the BWP
%   - When all the precoding matrices in a codebook are restricted
%   Also note that the PMI i2 index (or indices set) is reported as NaNs in
%   the subbands where CSI-RS is not present.
%
%   % Example:
%   % This example demonstrates how to calculate PMI.
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
%   nLayers = 1;
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
%   % Configure the parameters related to CSI reporting
%   reportConfig.NStartBWP = 0;
%   reportConfig.NSizeBWP = 52;
%   reportConfig.PanelDimensions = [2 1];
%   reportConfig.PMIMode = 'Subband';
%   reportConfig.SubbandSize = 4;
%   reportConfig.PRGSize = [];
%   reportConfig.CodebookMode = 2;
%   reportConfig.CodebookSubsetRestriction = [];
%   reportConfig.i2Restriction = [];
%
%   % Calculate the PMI values
%   [PMISet,PMIInfo] = hDLPMISelect(carrier,csirs,reportConfig,nLayers,H,nVar)

%   Copyright 2020-2023 The MathWorks, Inc.

    narginchk(5,6);
    if (nargin == 6)
        nVar = varargin{1};
    else
        % Consider a small noise variance value by default, if the noise
        % variance is not given
        nVar = 1e-10;
    end
    [reportConfig,csirsIndSubs,numCSIRSPorts,nVar] = validateInputs(carrier,csirs,reportConfig,nLayers,H,nVar);    

    % Set the below flags to identify the codebook type
    isType1SinglePanel = strcmpi(reportConfig.CodebookType,'Type1SinglePanel');
    isType1MultiPanel = strcmpi(reportConfig.CodebookType,'Type1MultiPanel');
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');
    isEnhType2 = strcmpi(reportConfig.CodebookType,'eType2');

    % Get the codebook
    [codebook,indexSetSizes] = getCodebook(reportConfig,numCSIRSPorts,nLayers);

    % Get the PMI subband related information
    subbandInfo = hDLPMISubbandInfo(carrier,reportConfig);

    % Get the CSI-RS indices in BWP resource grid and channel matrix
    % corresponding to the BWP REs. H is of size
    % K-by-L-by-nRxAnts-by-Pcsirs and H_bwp is of size
    % nRxAnts-by-Pcsirs-reportConfig.NSizeBWP*12-by-L
    [H_bwp,csirsIndBWP_k,csirsIndBWP_l,csirsIndBWP_p] = getCSIRSIndicesAndHInBWP(carrier,reportConfig,H,csirsIndSubs);
    
    % Generate PMI set and output information structure with NaNs
    [PMINaNSet,nanInfo] = getPMINaNSet(carrier,reportConfig,subbandInfo,codebook,indexSetSizes,numCSIRSPorts,nLayers,csirsIndBWP_k);
    
    % Report the outputs as all NaNs, if there are no CSI-RS resources
    % present in the BWP, or if all the elements in the channel matrix are
    % NaNs, or all the precoding matrices of  type I codebook are
    % restricted
    if isempty(csirsIndBWP_k) || all(isnan(H_bwp(:))) ||...
        ((isType1SinglePanel || isType1MultiPanel) && (~any(codebook(:))))       
        PMISet = PMINaNSet;
        info = nanInfo;
        return;
    end

    % Compute PMI
    Htemp = reshape(H_bwp,size(H_bwp,1),size(H_bwp,2),[]);
    Hcsirs = Htemp(:,:,csirsIndBWP_k+(csirsIndBWP_l-1)*size(H_bwp,3)); % Channel matrices at CSI-RS locations
    if isType2 || isEnhType2
        [W,PMISet,SubbandSINRs,wbInfo] = getTypeIIPMIWideband(reportConfig,Hcsirs,nLayers,nVar,PMINaNSet);
        if all(isnan(W))
            PMISet = PMINaNSet;
            info = nanInfo;
            return;
        end
        SINRPerRE = computeSINRPerRE(Hcsirs,W,nVar,csirsIndBWP_k,indexSetSizes);
        SINRPerREPMI = SINRPerRE;
    else
        SINRPerRE = computeSINRPerRE(Hcsirs,codebook,nVar,csirsIndBWP_k,indexSetSizes);
        [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIPMIWideband(reportConfig,SINRPerRE,codebook,indexSetSizes);
    end

    % Get the number of subbands
    numSubbands = subbandInfo.NumSubbands;       
    if numSubbands > 1 || (isType2 && reportConfig.SubbandAmplitude)
        if isType2 || isEnhType2
            [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIIPMISubband(reportConfig,H_bwp,nVar,nLayers,csirsIndBWP_k,csirsIndBWP_l,PMISet,wbInfo,subbandInfo,indexSetSizes);
        else
            [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIPMISubband(carrier,reportConfig,codebook,PMISet,SINRPerRE,subbandInfo,indexSetSizes,csirsIndBWP_k,csirsIndBWP_l);
        end
    end

    % Form the output
    if isType1SinglePanel || isType1MultiPanel  % Type I codebooks                      
        SINRPerREOut = SINRPerRE;         % SINR value per RE for all the layers for all PMI indices
        codebookOut = codebook;           % PMI codebook containing the precoding matrices corresponding to all PMI indices
        % SINR value per subband for all the layers for all PMI indices
        SubbandSINRs = reshape(SubbandSINRs,[subbandInfo.NumSubbands,nLayers,indexSetSizes]);
    else % Type II codebooks
        SINRPerREOut = [];
        codebookOut = [];
    end
    info.SINRPerRE = SINRPerREOut;
    info.SINRPerREPMI = SINRPerREPMI;   % SINR value per RE for all the layers for the reported PMI
    info.Codebook = codebookOut;
    info.SINRPerSubband = SubbandSINRs; % SINR value per subband for all the layers for the reported PMI
    info.W = W;                         % Precoding matrix corresponding to the reported PMI
    info.CSIRSIndices = [csirsIndBWP_k csirsIndBWP_l csirsIndBWP_p]; % CSI-RS RE indices where the SINR value per RE are calculated
end

function [reportConfig,csirsInd,NumCSIRSPorts,nVar] = validateInputs(carrier,csirs,reportConfig,nLayers,H,nVar)
%   [REPORTCONFIG,CSIRSIND,NUMCSIRSPORTS,NVAR] = validateInputs(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H,NVAR)
%   validates the inputs arguments and returns the validated CSI report
%   configuration structure REPORTCONFIG along with the NZP-CSI-RS indices
%   CSIRSIND and noise variance NVAR.

    fcnName = 'hDLPMISelect';
    validateattributes(carrier,{'nrCarrierConfig'},{'scalar'},fcnName,'CARRIER');
    % Validate 'csirs'
    validateattributes(csirs,{'nrCSIRSConfig'},{'scalar'},fcnName,'CSIRS');
    if ~isscalar(unique(csirs.NumCSIRSPorts))
        error('nr5g:hDLPMISelect:InvalidCSIRSPorts',...
            'All the CSI-RS resources must be configured to have the same number of CSI-RS ports.');
    end
    if iscell(csirs.CDMType)
        cdmType = csirs.CDMType;
    else
        cdmType = {csirs.CDMType};
    end
    if ~all(strcmpi(cdmType,cdmType{1}))
        error('nr5g:hDLPMISelect:InvalidCSIRSCDMTypes',...
            'All the CSI-RS resources must be configured to have the same CDM lengths.');
    end

    % Validate 'reportConfig'
    % Validate 'NSizeBWP'
    if ~isfield(reportConfig,'NSizeBWP')
        error('nr5g:hDLPMISelect:NSizeBWPMissing','NSizeBWP field is mandatory.');
    end
    nSizeBWP = reportConfig.NSizeBWP;
    if ~(isnumeric(nSizeBWP) && isempty(nSizeBWP))
        validateattributes(nSizeBWP,{'double','single'},{'scalar','integer','positive','<=',275},fcnName,'the size of BWP');
    else
        nSizeBWP = carrier.NSizeGrid;
    end
    % Validate 'NStartBWP'
    if ~isfield(reportConfig,'NStartBWP')
        error('nr5g:hDLPMISelect:NStartBWPMissing','NStartBWP field is mandatory.');
    end
    nStartBWP = reportConfig.NStartBWP;
    if ~(isnumeric(nStartBWP) && isempty(nStartBWP))
        validateattributes(nStartBWP,{'double','single'},{'scalar','integer','nonnegative','<=',2473},fcnName,'the start of BWP');
    else
        nStartBWP = carrier.NStartGrid;
    end
    if nStartBWP < carrier.NStartGrid
        error('nr5g:hDLPMISelect:InvalidNStartBWP',...
            ['The starting resource block of BWP ('...
            num2str(nStartBWP) ') must be greater than '...
            'or equal to the starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ').']);
    end
    % Check whether BWP is located within the limits of carrier or not
    if (nSizeBWP + nStartBWP)>(carrier.NStartGrid + carrier.NSizeGrid)
        error('nr5g:hDLPMISelect:InvalidBWPLimits',['The sum of starting resource '...
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

    % Set the flags for the respective codebook types to use the parameters
    % accordingly
    isType1SinglePanel = strcmpi(reportConfig.CodebookType,'Type1SinglePanel');
    isType1MultiPanel = strcmpi(reportConfig.CodebookType,'Type1MultiPanel');
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');
    isEnhType2 = strcmpi(reportConfig.CodebookType,'eType2');

    % Validate 'CodebookMode'
    if isfield(reportConfig,'CodebookMode')
        validateattributes(reportConfig.CodebookMode,{'numeric'},...
            {'scalar','integer','positive','<=',2},fcnName,'CodebookMode field');
    else
        reportConfig.CodebookMode = 1;
    end

    % Validate 'PanelDimensions'
    N1 = 1;
    N2 = 1;
    O1 = 1;
    O2 = 1;
    NumCSIRSPorts = csirs.NumCSIRSPorts(1);
    if isType2
        codebookType = 'Type II';
        maxNLayers = 2;
    elseif isEnhType2
        codebookType = 'Enhanced Type II';
        maxNLayers = 4;
    elseif isType1SinglePanel
        codebookType = 'Type I Single-Panel';
        maxNLayers = 8;
    else
        codebookType = 'Type I Multi-Panel';
        maxNLayers = 4;
    end
    if ~isType1MultiPanel
        if NumCSIRSPorts > 2
            if ~isfield(reportConfig,'PanelDimensions')
                error('nr5g:hDLPMISelect:PanelDimensionsMissing',...
                    'PanelDimensions field is mandatory.');
            end
            validateattributes(reportConfig.PanelDimensions,...
                {'double','single'},{'vector','numel',2},fcnName,['PanelDimensions field for ' codebookType ' codebooks']);
            N1 = reportConfig.PanelDimensions(1);
            N2 = reportConfig.PanelDimensions(2);
            Pcsirs = 2*prod(reportConfig.PanelDimensions);
            if Pcsirs ~= NumCSIRSPorts
                error('nr5g:hDLPMISelect:InvalidPanelDimensions',...
                    ['For the configured number of CSI-RS ports (' num2str(NumCSIRSPorts)...
                    '), the given panel configuration [' num2str(N1) ' ' num2str(N2)...
                    '] is not valid. Note that, two times the product of panel dimensions ('...
                    num2str(Pcsirs) ') must be equal to the number of CSI-RS ports (' num2str(NumCSIRSPorts) ').']);
            end
            % Supported panel configurations and oversampling factors for
            % type I single-panel codebooks, as defined in
            % TS 38.214 Table 5.2.2.2.1-2
            panelConfigs = [2     2     4     3     6     4     8     4     6    12     4     8    16   % N1
                            1     2     1     2     1     2     1     3     2     1     4     2     1   % N2
                            4     4     4     4     4     4     4     4     4     4     4     4     4   % O1
                            1     4     1     4     1     4     1     4     4     1     4     4     1]; % O2
            configIdx = find(panelConfigs(1,:) == N1 & panelConfigs(2,:) == N2,1);
            if isempty(configIdx)
                error('nr5g:hDLPMISelect:InvalidPanelConfiguration',['The given panel configuration ['...
                    num2str(reportConfig.PanelDimensions(1)) ' ' num2str(reportConfig.PanelDimensions(2)) '] ' ...
                    'is not valid for the given CSI-RS configuration. '...
                    'For a number of CSI-RS ports, the panel configuration should ' ...
                    'be one of the possibilities from TS 38.214 Table 5.2.2.2.1-2.']);
            end

            % Extract the oversampling factors
            O1 = panelConfigs(3,configIdx);
            O2 = panelConfigs(4,configIdx);
        else
            if isType2 || isEnhType2
                error('nr5g:hDLPMISelect:InvalidCSIRSPortsConfigurationForType2',...
                    ['The minimum required number of CSI-RS ports for ' codebookType ' codebooks is 4.']);
            end
        end
    else
        if ~any(NumCSIRSPorts == [8 16 32])
            error('nr5g:hDLPMISelect:InvalidNumCSIRSPortsForMultiPanel',['For' ...
                ' type I multi-panel codebook type, the number of CSI-RS ports must be 8, 16, or 32.']);
        end
        if ~isfield(reportConfig,'PanelDimensions')
            error('nr5g:hDLPMISelect:PanelDimensionsMissing',...
                'PanelDimensions field is mandatory.');
        end
        validateattributes(reportConfig.PanelDimensions,...
            {'double','single'},{'vector','numel',3},fcnName,'PanelDimensions field for type I multi-panel codebooks');
        N1 = reportConfig.PanelDimensions(2);
        N2 = reportConfig.PanelDimensions(3);
        Pcsirs = 2*prod(reportConfig.PanelDimensions);
        Ng = reportConfig.PanelDimensions(1);
        if Pcsirs ~= NumCSIRSPorts
            error('nr5g:hDLPMISelect:InvalidMultiPanelDimensions',...
                ['For the configured number of CSI-RS ports (' num2str(NumCSIRSPorts)...
                '), the given panel configuration [' num2str(Ng) ' ' num2str(N1) ' ' num2str(N2)...
                '] is not valid. Note that, two times the product of panel dimensions ('...
                num2str(Pcsirs) ') must be equal to the number of CSI-RS ports (' num2str(NumCSIRSPorts) ').']);
        end
        % Supported panel configurations and oversampling factors for
        % type I multi-panel codebooks, as defined in
        % TS 38.214 Table 5.2.2.2.2-1
        panelConfigs = [2     2     2     4     2     2     4     4    % Ng
                        2     2     4     2     8     4     4     2    % N1
                        1     2     1     1     1     2     1     2    % N2
                        4     4     4     4     4     4     4     4    % O1
                        1     4     1     1     1     4     1     4 ]; % O2
        configIdx = find(panelConfigs(1,:) == Ng & panelConfigs(2,:) == N1 & panelConfigs(3,:) == N2,1);
        if isempty(configIdx)
            error('nr5g:hDLPMISelect:InvalidMultiPanelConfiguration',['The given panel configuration ['...
                num2str(Ng) ' ' num2str(N1) ' ' num2str(N2) ...
                '] is not valid for the given CSI-RS configuration. '...
                'For a number of CSI-RS ports, the panel configuration should ' ...
                'be one of the possibilities from TS 38.214 Table 5.2.2.2.2-1.']);
        end

        if reportConfig.CodebookMode == 2 && Ng ~= 2
            error('nr5g:hDLPMISelect:InvalidNumPanelsforGivenCodebookMode',['For' ...
                ' codebook mode 2, number of panels Ng (' num2str(Ng) ') must be 2.' ...
                ' Choose appropriate PanelDimensions.']);
        end
        % Extract the oversampling factors
        O1 = panelConfigs(4,configIdx);
        O2 = panelConfigs(5,configIdx);
    end
    reportConfig.OverSamplingFactors = [O1 O2];

    % Validate 'PMIMode'
    if isfield(reportConfig,'PMIMode')
        reportConfig.PMIMode = validatestring(reportConfig.PMIMode,{'Wideband','Subband'},fcnName,'PMIMode field');
    else
        reportConfig.PMIMode = 'Wideband';
    end

    % Validate 'PRGSize'
    if isfield(reportConfig,'PRGSize') && isType1SinglePanel
        if ~(isnumeric(reportConfig.PRGSize) && isempty(reportConfig.PRGSize))
            validateattributes(reportConfig.PRGSize,{'double','single'},...
                {'real','scalar'},fcnName,'PRGSize field');
        end
        if ~(isempty(reportConfig.PRGSize) || any(reportConfig.PRGSize == [2 4]))
            error('nr5g:hDLPMISelect:InvalidPRGSize',...
                ['PRGSize value (' num2str(reportConfig.PRGSize) ') must be [], 2, or 4.']);
        end
    else
        reportConfig.PRGSize = [];
    end

    % Validate 'SubbandSize'
    if strcmpi(reportConfig.PMIMode,'Subband') && isempty(reportConfig.PRGSize)
        if nSizeBWP >= 24
            if ~isfield(reportConfig,'SubbandSize')
                error('nr5g:hDLPMISelect:SubbandSizeMissing',...
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
                error('nr5g:hDLPMISelect:InvalidSubbandSize',['For the configured BWP size (' num2str(nSizeBWP) ...
                    '), subband size (' num2str(NSBPRB) ') must be ' num2str(validNSBPRBValues(1)) ...
                    ' or ' num2str(validNSBPRBValues(2)) '.']);
            end
        else
            reportConfig.SubbandSize = [];
        end
    else
        reportConfig.SubbandSize = [];
    end

    % Validate 'CodebookSubsetRestriction'
    if  isType1SinglePanel || isType1MultiPanel
        if NumCSIRSPorts > 2
            codebookLength = N1*O1*N2*O2;
            codebookSubsetRestriction = ones(1,codebookLength);
            if isfield(reportConfig,'CodebookSubsetRestriction') &&...
                    ~isempty(reportConfig.CodebookSubsetRestriction)
                codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
                validateattributes(codebookSubsetRestriction,...
                    {'numeric'},{'vector','binary','numel',codebookLength},fcnName,'CodebookSubsetRestriction field');
            end
        elseif NumCSIRSPorts == 2
            codebookSubsetRestriction = ones(1,6);
            if isfield(reportConfig,'CodebookSubsetRestriction') &&...
                    ~isempty(reportConfig.CodebookSubsetRestriction)
                codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
                validateattributes(codebookSubsetRestriction,{'numeric'},{'vector','binary','numel',6},fcnName,'CodebookSubsetRestriction field');
            end
        else
            codebookSubsetRestriction = 1;
        end
    else % Type II and enhanced type II codebooks
        if isfield(reportConfig,'CodebookSubsetRestriction') &&...
                    ~isempty(reportConfig.CodebookSubsetRestriction)
            codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
            if N2 == 1
                codebookLength = 8*N1*N2;
            else
                codebookLength = 11 + 8*N1*N2;
            end
            validateattributes(codebookSubsetRestriction,...
                    {'numeric'},{'vector','binary','numel',codebookLength},fcnName,'CodebookSubsetRestriction field');
        else
            codebookSubsetRestriction = [];
        end
        if isempty(codebookSubsetRestriction)
            if N2>1
                codebookSubsetRestriction = [ones(1,11) ones(1,4*2*N1*N2)];
            else
                codebookSubsetRestriction = ones(1,4*2*N1*N2);
            end
        end
    end
    reportConfig.CodebookSubsetRestriction = codebookSubsetRestriction;

    % Validate 'i2Restriction'
    i2Restriction = ones(1,16);
    if NumCSIRSPorts > 2 && isType1SinglePanel
        if isfield(reportConfig,'i2Restriction') &&  ~isempty(reportConfig.i2Restriction)
            validateattributes(reportConfig.i2Restriction,...
                {'numeric'},{'vector','binary','numel',16},fcnName,'i2Restriction field');
            i2Restriction = reportConfig.i2Restriction;
        end
    end
    reportConfig.i2Restriction = i2Restriction;

    if isType2
        % Validate 'NumberOfBeams'
        if ~isfield(reportConfig,'NumberOfBeams')
            error('nr5g:hDLPMISelect:NumberOfBeamsMissing',...
                'NumberOfBeams is a mandatory field.');
        end
        if ~any(reportConfig.NumberOfBeams == [2 3 4])
            error('nr5g:hDLPMISelect:InvalidNumberOfBeams',...
                ['NumberOfBeams value (' num2str(reportConfig.NumberOfBeams) ') must be 2, 3, or 4.']);
        end
        if NumCSIRSPorts == 4 && reportConfig.NumberOfBeams > 2
            error('nr5g:hDLPMISelect:InvalidNumberOfBeamsFor4Ports',...
                ['NumberOfBeams value (' num2str(reportConfig.NumberOfBeams) ') must be 2 when number of CSI-RS ports is 4.']);
        end

        % Validate 'PhaseAlphabetSize'
        if isfield(reportConfig,'PhaseAlphabetSize')
            if ~any(reportConfig.PhaseAlphabetSize == [4 8])
                error('nr5g:hDLPMISelect:InvalidPhaseAlphabetSize',...
                    ['PhaseAlphabetSize value (' num2str(reportConfig.PhaseAlphabetSize) ') must be 4 or 8.']);
            end
        else
            reportConfig.PhaseAlphabetSize = 4;
        end

        % Validate 'SubbandAmplitude'        
        if isfield(reportConfig,'SubbandAmplitude')
            validateattributes(reportConfig.SubbandAmplitude,{'logical','double'},{'nonempty'},fcnName,'SubbandAmplitude field');
        else
            reportConfig.SubbandAmplitude = false;
        end
    elseif isEnhType2
        % Validate 'ParameterCombination'
        if isfield(reportConfig,'ParameterCombination')
            validateattributes(reportConfig.ParameterCombination,{'numeric'}, ...
                {'scalar','integer','positive','<=',8},fcnName,...
                ['PARAMETERCOMBINATION(' num2str(reportConfig.ParameterCombination) ') when codebook type is "eType2"']);
        else
            reportConfig.ParameterCombination = 1; % Default value
        end
        if NumCSIRSPorts == 4
            if reportConfig.ParameterCombination >= 3
                error('nr5g:hDLPMISelect:InvalidParameterCombination',...
                    ['For enhanced type II codebooks, ParameterCombination value (' num2str(reportConfig.ParameterCombination) ') must be less than 3 when the number of CSI-RS ports is 4.'])
            end
        end
        if NumCSIRSPorts < 32
            if reportConfig.ParameterCombination >= 7
                error('nr5g:hDLPMISelect:InvalidParameterCombination',...
                    ['For enhanced type II codebooks, ParameterCombination value (' num2str(reportConfig.ParameterCombination) ') must be less than 7 when the number of CSI-RS ports is less than 32.'])
            end
        end        

        % Validate 'NumberOfPMISubbandsPerCQISubband'
        if isfield(reportConfig,'NumberOfPMISubbandsPerCQISubband')
            if ~any(reportConfig.NumberOfPMISubbandsPerCQISubband == [1 2])
                error('nr5g:hDLPMISelect:InvalidNumberOfPMISubbandsPerCQISubband',...
                    ['For enhanced type II codebooks, NumberOfPMISubbandsPerCQISubband value (' num2str(reportConfig.NumberOfPMISubbandsPerCQISubband) ') must be 1 or 2.']);
            end
        else
            reportConfig.NumberOfPMISubbandsPerCQISubband = 1; % Default value
        end

        if reportConfig.ParameterCombination >= 7 && reportConfig.NumberOfPMISubbandsPerCQISubband == 2
            error('nr5g:hDLPMISelect:InvalidParameterCombination',...
                    ['For enhanced type II codebooks, ParameterCombination value (' num2str(reportConfig.ParameterCombination) ') must be less than 7 when NumberOfPMISubbandsPerCQISubband value is 2.'])
        end
    end

    % Validate 'nLayers'
    validateattributes(nLayers,{'numeric'},{'scalar','integer','positive','<=',maxNLayers},fcnName,['NLAYERS(' num2str(nLayers) ') for ' codebookType ' codebooks']);
    if isEnhType2
        % Update or add NumberOfBeams to reportConfig as it is used in
        % intialization of PMI outputs
        [reportConfig.NumberOfBeams,reportConfig.pv,reportConfig.beta] = getEnhancedType2ParameterCombinations(reportConfig.ParameterCombination,nLayers);
        reportConfig.PhaseAlphabetSize = 16; % 16-PSK

        if nLayers > 2
            if reportConfig.ParameterCombination >= 7
                error('nr5g:hDLPMISelect:InvalidParameterCombination',...
                    ['For enhanced type II codebooks, ParameterCombination value (' num2str(reportConfig.ParameterCombination) ') must be less than 7 when the number of transmission layers is 3, or 4.'])
            end
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
    tempInd = tempInd(numZPCSIRSRes+1:end)'; % NZP-CSI-RS indices
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
    if ~isempty(csirsInd)
        K = carrier.NSizeGrid*12;
        L = carrier.SymbolsPerSlot;
        validateattributes(H,{class(H)},{'size',[K L NaN NumCSIRSPorts]},fcnName,'H');

        % Validate 'nLayers'
        nRxAnts = size(H,3);
        maxPossibleNLayers = min(nRxAnts,NumCSIRSPorts);
        if nLayers > maxPossibleNLayers
            error('nr5g:hDLPMISelect:InvalidNumLayers',...
                ['The given antenna configuration (' ...
                num2str(NumCSIRSPorts) 'x' num2str(nRxAnts)...
                ') supports only up to (' num2str(maxPossibleNLayers) ') layers.']);
        end
    end

    % Validate 'nVar'
    validateattributes(nVar,{'double','single'},{'scalar','real','nonnegative','finite'},fcnName,'NVAR');
    % Clip 'nVar' to a small noise variance to avoid +/-Inf outputs
    if nVar < 1e-10
        nVar = 1e-10;
    end
end

function [codebook,indexSetSizes] = getCodebook(reportConfig,numCSIRSPorts,nLayers)
%   [codebook,indexSetSizes] = getCodebook(reportConfig,numCSIRSPorts,nLayers)
%   returns the codebook and the corresponding indices set sizes

    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        if numCSIRSPorts == 1
            % Codebook is a scalar with the value 1, when the number of CSI-RS
            % ports is 1
            codebook = 1;
        else
            % Codebook is a multidimensional matrix of size
            % Pcsirs-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
            % or Pcsirs-by-nLayers-by-i2Length based on the number of
            % CSI-RS ports
            codebook = getPMIType1SinglePanelCodebook(reportConfig,numCSIRSPorts,nLayers);
        end
        % Get the size of Codebook
        [~,~,i2Length,i11Length,i12Length,i13Length] = size(codebook);

        % Store the sizes of the indices in a variable
        indexSetSizes = [i2Length,i11Length,i12Length,i13Length];
    elseif strcmpi(reportConfig.CodebookType,'Type1MultiPanel')
        % Codebook is a multidimensional matrix of size
        % Pcsirs-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
        codebook = getPMIType1MultiPanelCodebook(reportConfig,nLayers);
        [~,~,i20Length,i21Length,i22Length,i11Length,i12Length,i13Length,i141Length,i142Length,i143Length] = size(codebook);

        % Store the sizes of the indices in a variable
        indexSetSizes = [i20Length,i21Length,i22Length,i11Length,i12Length,i13Length,i141Length,i142Length,i143Length];
    else % Type II codebooks or enhanced type II codebooks
        codebook = [];
        indexSetSizes = 1; % To represent single precoder reported foor type 2 and enhanced type 2
    end
end

function  codebook = getPMIType1SinglePanelCodebook(reportConfig,Pcsirs,nLayers)
%   CODEBOOK = getPMIType1SinglePanelCodebook(REPORTCONFIG,PCSIRS,NLAYERS)
%   returns a codebook CODEBOOK containing type I single-panel precoding
%   matrices, as defined in TS 38.214 Tables 5.2.2.2.1-1 to 5.2.2.2.1-12 by
%   considering these inputs:
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   PanelDimensions            - Antenna panel configuration as a
%                                two-element vector ([N1 N2]). It is not
%                                applicable for CSI-RS ports less than or
%                                equal to 2
%   OverSamplingFactors        - DFT oversampling factors corresponding to
%                                the panel configuration
%   CodebookMode               - Codebook mode. Applicable only when the
%                                number of MIMO layers is 1 or 2 and
%                                number of CSI-RS ports is greater than 2
%   CodebookSubsetRestriction  - Binary vector for vlm or vbarlm restriction
%   i2Restriction              - Binary vector for i2 restriction
%
%   NLAYERS      - Number of transmission layers
%
%   CODEBOOK     - Multidimensional array containing unrestricted type I
%                  single-panel precoding matrices. It is of size
%                  Pcsirs-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%
%   Note that the restricted precoding matrices are returned as all zeros.

    codebookMode              = reportConfig.CodebookMode;
    codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
    i2Restriction             = reportConfig.i2Restriction;

    % Create a function handle to compute the co-phasing factor value
    % according to TS 38.214 Section 5.2.2.2.1, considering the co-phasing
    % factor index
    phi = @(x)exp(1i*pi*x/2);

    % Get the codebook
    if Pcsirs == 2
        % Codebooks for 1-layer and 2-layer CSI reporting using antenna
        % ports 3000 to 3001, as defined in TS 38.214 Table 5.2.2.2.1-1
        if nLayers == 1
            codebook(:,:,1) = 1/sqrt(2).*[1; 1];
            codebook(:,:,2) = 1/sqrt(2).*[1; 1i];
            codebook(:,:,3) = 1/sqrt(2).*[1; -1];
            codebook(:,:,4) = 1/sqrt(2).*[1; -1i];
            restrictedIndices = find(~codebookSubsetRestriction);
            restrictedIndices = restrictedIndices(restrictedIndices <= 4);
            if ~isempty(restrictedIndices)
                restrictedSet = logical(sum(restrictedIndices == [1;2;3;4],2));
                codebook(:,:,restrictedSet) = 0;
            end
        elseif nLayers == 2
            codebook(:,:,1) = 1/2*[1 1;1 -1];
            codebook(:,:,2) = 1/2*[1 1; 1i -1i];
            restrictedIndices = find(~codebookSubsetRestriction);
            restrictedIndices = restrictedIndices(restrictedIndices > 4);
            if ~isempty(restrictedIndices)
                restrictedSet = logical(sum(restrictedIndices == [5;6],2));
                codebook(:,:,restrictedSet) = 0;
            end
        end
    elseif Pcsirs > 2
        panelDimensions = reportConfig.PanelDimensions;
        N1 = panelDimensions(1);
        N2 = panelDimensions(2);
        O1 = reportConfig.OverSamplingFactors(1);
        O2 = reportConfig.OverSamplingFactors(2);

        % Select the codebook based on the number of layers, panel
        % configuration, and the codebook mode
        switch nLayers
            case 1 % Number of layers is 1
                % Codebooks for 1-layer CSI reporting using antenna ports
                % 3000 to 2999+P_CSIRS, as defined in TS 38.214 Table
                % 5.2.2.2.1-5
                if codebookMode == 1
                    i11_length = N1*O1;
                    i12_length = N2*O2;
                    i2_length = 4;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                    % Loop over all the values of i11, i12, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i2 = 0:i2_length-1
                                l = i11;
                                m = i12;
                                n = i2;
                                bitIndex = N2*O2*l+m;
                                [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                if ~(lmRestricted || i2Restricted)
                                    vlm = getVlm(N1,N2,O1,O2,l,m);
                                    phi_n = phi(n);
                                    codebook(:,:,i2+1,i11+1,i12+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                        phi_n*vlm];
                                end
                            end
                        end
                    end
                else % codebookMode == 2
                    i11_length = N1*O1/2;
                    i12_length = N2*O2/2;
                    if N2 == 1
                        i12_length = 1;
                    end
                    i2_length = 16;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                    % Loop over all the values of i11, i12, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i2 = 0:i2_length-1
                                floor_i2by4 = floor(i2/4);
                                if N2 == 1
                                    l = 2*i11 + floor_i2by4;
                                    m = 0;
                                else % N2 > 1
                                    lmAddVals = [0 0; 1 0; 0 1;1 1];
                                    l = 2*i11 + lmAddVals(floor_i2by4+1,1);
                                    m = 2*i12 + lmAddVals(floor_i2by4+1,2);
                                end
                                n = mod(i2,4);
                                bitIndex = N2*O2*l+m;
                                [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                if ~(lmRestricted || i2Restricted)
                                    vlm = getVlm(N1,N2,O1,O2,l,m);
                                    phi_n = phi(n);
                                    codebook(:,:,i2+1,i11+1,i12+1) = (1/sqrt(Pcsirs))*[vlm;...
                                        phi_n*vlm];
                                end
                            end
                        end
                    end
                end

            case 2 % Number of layers is 2
                % Codebooks for 2-layer CSI reporting using antenna ports
                % 3000 to 2999+P_CSIRS, as defined in TS 38.214 Table
                % 5.2.2.2.1-6

                % Compute i13 parameter range and corresponding k1 and k2,
                % as defined in TS 38.214 Table 5.2.2.2.1-3
                if (N1 > N2) && (N2 > 1)
                    i13_length = 4;
                    k1 = [0 O1 0 2*O1];
                    k2 = [0 0 O2 0];
                elseif N1 == N2
                    i13_length = 4;
                    k1 = [0 O1 0 O1];
                    k2 = [0 0 O2 O2];
                elseif (N1 == 2) && (N2 == 1)
                    i13_length = 2;
                    k1 = O1*(0:1);
                    k2 = [0 0];
                else
                    i13_length = 4;
                    k1 = O1*(0:3);
                    k2 = [0 0 0 0] ;
                end

                if codebookMode == 1
                    i11_length = N1*O1;
                    i12_length = N2*O2;
                    i2_length = 2;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    l = i11;
                                    m = i12;
                                    n = i2;
                                    lPrime = i11+k1(i13+1);
                                    mPrime = i12+k2(i13+1);
                                    bitIndex = N2*O2*l+m;
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vlm = getVlm(N1,N2,O1,O2,l,m);
                                        vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                        phi_n = phi(n);
                                        codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                            (1/sqrt(2*Pcsirs))*[vlm        vlPrime_mPrime;...
                                            phi_n*vlm  -phi_n*vlPrime_mPrime];
                                    end
                                end
                            end
                        end
                    end
                else % codebookMode == 2
                    i11_length = N1*O1/2;
                    if N2 == 1
                        i12_length = 1;
                    else
                        i12_length = N2*O2/2;
                    end
                    i2_length = 8;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    floor_i2by2 = floor(i2/2);
                                    if N2 == 1
                                        l = 2*i11 + floor_i2by2;
                                        lPrime = 2*i11 + floor_i2by2 + k1(i13+1);
                                        m = 0;
                                        mPrime = 0;
                                    else % N2 > 1
                                        lmAddVals = [0 0; 1 0; 0 1;1 1];
                                        l = 2*i11 + lmAddVals(floor_i2by2+1,1);
                                        lPrime =  2*i11 + k1(i13+1) + lmAddVals(floor_i2by2+1,1);
                                        m = 2*i12 + lmAddVals(floor_i2by2+1,2);
                                        mPrime =  2*i12 + k2(i13+1) + lmAddVals(floor_i2by2+1,2);
                                    end
                                    n = mod(i2,2);
                                    bitIndex = N2*O2*l+m;
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vlm = getVlm(N1,N2,O1,O2,l,m);
                                        vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                        phi_n = phi(n);
                                        codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                            (1/sqrt(2*Pcsirs))*[vlm        vlPrime_mPrime;...
                                            phi_n*vlm  -phi_n*vlPrime_mPrime];
                                    end
                                end
                            end
                        end
                    end
                end

            case {3,4} % Number of layers is 3 or 4
                if (Pcsirs < 16)
                    % For the number of CSI-RS ports less than 16, compute
                    % i13 parameter range, corresponding k1 and k2,
                    % according to TS 38.214 Table 5.2.2.2.1-4
                    if (N1 == 2) && (N2 == 1)
                        i13_length = 1;
                        k1 = O1;
                        k2 = 0;
                    elseif (N1 == 4) && (N2 == 1)
                        i13_length = 3;
                        k1 = O1*(1:3);
                        k2 = [0 0 0];
                    elseif (N1 == 6) && (N2 == 1)
                        i13_length = 4;
                        k1 = O1*(1:4);
                        k2 = [0 0 0 0];
                    elseif (N1 == 2) && (N2 == 2)
                        i13_length = 3;
                        k1 = [O1 0 O1];
                        k2 = [0 O2 O2];
                    elseif (N1 == 3) && (N2 == 2)
                        i13_length = 4;
                        k1 = [O1 0 O1 2*O1];
                        k2 = [0 O2 O2 0];
                    end

                    % For 3 and 4 layers the procedure for computation of W
                    % is same, other than the dimensions of W. Compute W
                    % for either case accordingly
                    i11_length = N1*O1;
                    i12_length = N2*O2;
                    i2_length = 2;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    l = i11;
                                    lPrime = i11+k1(i13+1);
                                    m = i12;
                                    mPrime = i12+k2(i13+1);
                                    n = i2;
                                    bitIndex = N2*O2*l+m;
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vlm = getVlm(N1,N2,O1,O2,l,m);
                                        vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                        phi_n = phi(n);
                                        phi_vlm = phi_n*vlm;
                                        phi_vlPrime_mPrime = phi_n*vlPrime_mPrime;
                                        if nLayers == 3
                                            % Codebook for 3-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-7
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(3*Pcsirs))*[vlm      vlPrime_mPrime      vlm;...
                                                phi_vlm  phi_vlPrime_mPrime  -phi_vlm];
                                        else
                                            % Codebook for 4-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-8
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(4*Pcsirs))*[vlm      vlPrime_mPrime      vlm       vlPrime_mPrime;...
                                                phi_vlm  phi_vlPrime_mPrime  -phi_vlm  -phi_vlPrime_mPrime];
                                        end
                                    end
                                end
                            end
                        end
                    end
                else % Number of CSI-RS ports is greater than or equal to 16
                    i11_length = N1*O1/2;
                    i12_length = N2*O2;
                    i13_length = 4;
                    i2_length = 2;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    theta = exp(1i*pi*i13/4);
                                    l = i11;
                                    m = i12;
                                    n = i2;
                                    phi_n = phi(n);
                                    bitValues = [mod(N2*O2*(2*l-1)+m,N1*O1*N2*O2), N2*O2*(2*l)+m, N2*O2*(2*l+1)+m];
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitValues,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vbarlm = getVbarlm(N1,N2,O1,O2,l,m);
                                        theta_vbarlm = theta*vbarlm;
                                        phi_vbarlm = phi_n*vbarlm;
                                        phi_theta_vbarlm = phi_n*theta*vbarlm;
                                        if nLayers == 3
                                            % Codebook for 3-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-7
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(3*Pcsirs))*[vbarlm            vbarlm             vbarlm;...
                                                theta_vbarlm      -theta_vbarlm      theta_vbarlm;...
                                                phi_vbarlm        phi_vbarlm         -phi_vbarlm;...
                                                phi_theta_vbarlm  -phi_theta_vbarlm  -phi_theta_vbarlm];
                                        else
                                            % Codebook for 4-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-8
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(4*Pcsirs))*[vbarlm            vbarlm             vbarlm             vbarlm;...
                                                theta_vbarlm      -theta_vbarlm      theta_vbarlm       -theta_vbarlm;...
                                                phi_vbarlm        phi_vbarlm         -phi_vbarlm        -phi_vbarlm;...
                                                phi_theta_vbarlm  -phi_theta_vbarlm  -phi_theta_vbarlm  phi_theta_vbarlm];
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

            case {5,6} % Number of layers is 5 or 6
                i11_length = N1*O1;
                if N2 == 1
                    i12_length = 1;
                else % N2 > 1
                    i12_length = N2*O2;
                end
                i2_length = 2;
                codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                % Loop over all the values of i11, i12, and i2
                for i11 = 0:i11_length-1
                    for i12 = 0:i12_length-1
                        for i2 = 0:i2_length-1
                            if N2 == 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11+2*O1;
                                m = 0;
                                mPrime = 0;
                                m_dPrime = 0;
                            else % N2 > 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11+O1;
                                m = i12;
                                mPrime = i12;
                                m_dPrime = i12+O2;
                            end
                            n = i2;
                            bitIndex = N2*O2*l+m;
                            [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                            if ~(lmRestricted || i2Restricted)
                                vlm = getVlm(N1,N2,O1,O2,l,m);
                                vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                vlDPrime_mDPrime = getVlm(N1,N2,O1,O2,l_dPrime,m_dPrime);
                                phi_n = phi(n);
                                phi_vlm = phi_n*vlm;
                                phi_vlPrime_mPrime = phi_n*vlPrime_mPrime;
                                if nLayers == 5
                                    % Codebook for 5-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-9
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(5*Pcsirs))*[vlm       vlm        vlPrime_mPrime   vlPrime_mPrime    vlDPrime_mDPrime;...
                                        phi_vlm   -phi_vlm   vlPrime_mPrime   -vlPrime_mPrime   vlDPrime_mDPrime];
                                else
                                    % Codebook for 6-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-10
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(6*Pcsirs))*[vlm       vlm        vlPrime_mPrime       vlPrime_mPrime        vlDPrime_mDPrime   vlDPrime_mDPrime;...
                                        phi_vlm   -phi_vlm   phi_vlPrime_mPrime   -phi_vlPrime_mPrime   vlDPrime_mDPrime   -vlDPrime_mDPrime];
                                end
                            end
                        end
                    end
                end

            case{7,8} % Number of layers is 7 or 8
                if N2 == 1
                    i12_length = 1;
                    if N1 == 4
                        i11_length = N1*O1/2;
                    else % N1 > 4
                        i11_length = N1*O1;
                    end
                else % N2 > 1
                    i11_length = N1*O1;
                    if (N1 == 2 && N2 == 2) || (N1 > 2 && N2 > 2)
                        i12_length = N2*O2;
                    else % (N1 > 2 && N2 == 2)
                        i12_length = N2*O2/2;
                    end
                end
                i2_length = 2;
                codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                % Loop over all the values of i11, i12, and i2
                for i11 = 0:i11_length-1
                    for i12 = 0:i12_length-1
                        for i2 = 0:i2_length-1
                            if N2 == 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11+2*O1;
                                l_tPrime = i11+3*O1;
                                m = 0;
                                mPrime = 0;
                                m_dPrime = 0;
                                m_tPrime = 0;
                            else % N2 > 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11;
                                l_tPrime = i11+O1;
                                m = i12;
                                mPrime = i12;
                                m_dPrime = i12+O2;
                                m_tPrime = i12+O2;
                            end
                            n = i2;
                            bitIndex = N2*O2*l+m;
                            [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                            if ~(lmRestricted || i2Restricted)
                                vlm = getVlm(N1,N2,O1,O2,l,m);
                                vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                vlDPrime_mDPrime = getVlm(N1,N2,O1,O2,l_dPrime,m_dPrime);
                                vlTPrime_mTPrime = getVlm(N1,N2,O1,O2,l_tPrime,m_tPrime);
                                phi_n = phi(n);
                                phi_vlm = phi_n*vlm;
                                phi_vlPrime_mPrime = phi_n*vlPrime_mPrime;
                                if nLayers == 7
                                    % Codebook for 7-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-11
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(7*Pcsirs))*[vlm       vlm        vlPrime_mPrime       vlDPrime_mDPrime   vlDPrime_mDPrime    vlTPrime_mTPrime   vlTPrime_mTPrime;...
                                        phi_vlm   -phi_vlm   phi_vlPrime_mPrime   vlDPrime_mDPrime   -vlDPrime_mDPrime   vlTPrime_mTPrime   -vlTPrime_mTPrime];
                                else
                                    % Codebook for 8-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-12
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(8*Pcsirs))*[vlm       vlm        vlPrime_mPrime       vlPrime_mPrime        vlDPrime_mDPrime   vlDPrime_mDPrime    vlTPrime_mTPrime   vlTPrime_mTPrime;...
                                        phi_vlm   -phi_vlm   phi_vlPrime_mPrime   -phi_vlPrime_mPrime   vlDPrime_mDPrime   -vlDPrime_mDPrime   vlTPrime_mTPrime   -vlTPrime_mTPrime];
                                end
                            end
                        end
                    end
                end
        end
    end
end

function codebook = getPMIType1MultiPanelCodebook(reportConfig,nLayers)
%   CODEBOOK = getPMIType1MultiPanelCodebook(REPORTCONFIG,NLAYERS) returns
%   a codebook CODEBOOK containing type I multi-panel precoding matrices, as
%   defined in TS 38.214 Tables 5.2.2.2.2-1 to 5.2.2.2.2-6 by considering
%   these inputs:
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   PanelDimensions            - Antenna panel configuration as a
%                                three-element vector ([Ng N1 N2]),
%                                as defined in TS 38.214 Table
%                                5.2.2.2.2-1
%   OverSamplingFactors        - DFT oversampling factors
%                                corresponding to the panel
%                                configuration
%   CodebookMode               - Codebook mode
%   CodebookSubsetRestriction  - Binary vector for vlm restriction
%
%   NLAYERS      - Number of transmission layers
%
%   CODEBOOK     - Multidimensional array containing unrestricted type I
%                  multi-panel precoding matrices. It is of size
%                  Pcsirs-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-i141Length-by-i142Length-by-i143Length
%
%   Note that the restricted precoding matrices are returned as all zeros.

    % Extract the panel dimensions
    Ng = reportConfig.PanelDimensions(1);
    N1 = reportConfig.PanelDimensions(2);
    N2 = reportConfig.PanelDimensions(3);

    % Extract the oversampling factors
    O1 = reportConfig.OverSamplingFactors(1);
    O2 = reportConfig.OverSamplingFactors(2);

    % Compute the number of ports
    Pcsirs = 2*Ng*N1*N2;

    % Create function handles to compute the co-phasing factor values
    % according to TS 38.214 Section 5.2.2.2.2, considering the co-phasing
    % factor indices
    phi = @(x)exp(1i*pi*x/2);
    a = @(x)exp(1i*pi/4 + 1i*pi*x/2);
    b = @(x)exp(-1i*pi/4 + 1i*pi*x/2);

    % Set the lengths of the common parameters to both codebook modes and
    % all the panel dimensions
    i11_length = N1*O1;
    i12_length = N2*O2;
    i13_length = 1; % Update this value according to number of layers
    i20_length = 2;
    i141_length = 4;

    % Set the lengths of the parameters respective to the codebook mode.
    % Consider the length of undefined values for a particular codebook
    % mode and/or number of panels as 1
    if reportConfig.CodebookMode == 1
        if Ng == 2
            i142_length = 1;
            i143_length = 1;
        else
            i142_length = 4;
            i143_length = 4;
        end
        i21_length = 1;
        i22_length = 1;
    else
        i142_length = 4;
        i143_length = 1;
        i21_length = 2;
        i22_length = 2;
    end

    % Select the codebook based on the number of layers, panel
    % configuration, and the codebook mode
    switch nLayers
        case 1 % Number of layers is 1
            i13_length = 1;
            i20_length = 4;
            codebook = zeros(Pcsirs,nLayers,i20_length,i21_length,i22_length,i11_length,i12_length,i13_length,i141_length,i142_length,i143_length);
            % Loop over all the values of all the indices
            for i11 = 0:i11_length-1
                for i12 = 0:i12_length-1
                    for i13 = 0:i13_length-1
                        l = i11;
                        m = i12;
                        bitIndex = N2*O2*l+m;
                        lmRestricted = isRestricted(reportConfig.CodebookSubsetRestriction,bitIndex,[],reportConfig.i2Restriction);
                        if ~(lmRestricted)
                            vlm = getVlm(N1,N2,O1,O2,l,m);
                            for i141 = 0:i141_length-1
                                for i142 = 0:i142_length-1
                                    for i143 = 0:i143_length-1
                                        for i20 = 0:i20_length-1
                                            for i21 = 0:i21_length-1
                                                for i22 = 0:i22_length-1
                                                    if reportConfig.CodebookMode == 1
                                                        n = i20;
                                                        phi_n = phi(n);
                                                        if Ng == 2
                                                            p = i141;
                                                            phi_p = phi(p);
                                                            % Codebook for 1-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-3
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                                                phi_n*vlm;...
                                                                phi_p*vlm;...
                                                                phi_n*phi_p*vlm];
                                                        else % Ng is 4
                                                            p1 = i141;
                                                            p2 = i142;
                                                            p3 = i143;
                                                            phi_p1 = phi(p1);
                                                            phi_p2 = phi(p2);
                                                            phi_p3 = phi(p3);
                                                            % Codebook for 1-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-3
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                                                phi_n*vlm;...
                                                                phi_p1*vlm;...
                                                                phi_n*phi_p1*vlm
                                                                phi_p2*vlm ;...
                                                                phi_n*phi_p2*vlm;...
                                                                phi_p3*vlm;...
                                                                phi_n*phi_p3*vlm];
                                                        end
                                                    else % Codebook mode 2
                                                        n0 = i20;
                                                        phi_n0 = phi(n0);
                                                        p1 = i141;
                                                        ap1 = a(p1);
                                                        n1 = i21;
                                                        bn1 = b(n1);
                                                        p2 = i142;
                                                        ap2 = a(p2);
                                                        n2 = i22;
                                                        bn2 = b(n2);
                                                        % Codebook for 1-layer CSI
                                                        % reporting using antenna ports
                                                        % 3000 to 2999+P_CSIRS, as
                                                        % defined in TS 38.214 Table
                                                        % 5.2.2.2.2-3
                                                        codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                                            phi_n0*vlm;...
                                                            ap1*bn1*vlm;...
                                                            ap2*bn2*vlm];

                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        case 2 % Number of layers is 2
            % Compute i13 parameter range and corresponding k1 and k2,
            % as defined in TS 38.214 Table 5.2.2.2.1-3
            if (N1 > N2) && (N2 > 1)
                i13_length = 4;
                k1 = [0 O1 0 2*O1];
                k2 = [0 0 O2 0];
            elseif N1 == N2
                i13_length = 4;
                k1 = [0 O1 0 O1];
                k2 = [0 0 O2 O2];
            elseif (N1 == 2) && (N2 == 1)
                i13_length = 2;
                k1 = O1*(0:1);
                k2 = [0 0];
            else
                i13_length = 4;
                k1 = O1*(0:3);
                k2 = [0 0 0 0] ;
            end
            codebook = zeros(Pcsirs,nLayers,i20_length,i21_length,i22_length,i11_length,i12_length,i13_length,i141_length,i142_length,i143_length);
            % Loop over all the values of all the indices
            for i11 = 0:i11_length-1
                for i12 = 0:i12_length-1
                    for i13 = 0:i13_length-1
                        l = i11;
                        m = i12;
                        lPrime = i11 + k1(i13+1);
                        mPrime = i12 + k2(i13+1);
                        bitIndex = N2*O2*l+m;
                        lmRestricted = isRestricted(reportConfig.CodebookSubsetRestriction,bitIndex,[],reportConfig.i2Restriction);
                        if ~(lmRestricted)
                            vlm = getVlm(N1,N2,O1,O2,l,m);
                            vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                            for i141 = 0:i141_length-1
                                for i142 = 0:i142_length-1
                                    for i143 = 0:i143_length-1
                                        for i20 = 0:i20_length-1
                                            for i21 = 0:i21_length-1
                                                for i22 = 0:i22_length-1
                                                    if reportConfig.CodebookMode == 1
                                                        n = i20;
                                                        phi_n = phi(n);
                                                        if Ng == 2
                                                            p = i141;
                                                            phi_p = phi(p);
                                                            % Codebook for 2-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-4
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(nLayers*Pcsirs))*[vlm                vlPrime_mPrime;...
                                                                phi_n*vlm         -phi_n*vlPrime_mPrime;...
                                                                phi_p*vlm          phi_p*vlPrime_mPrime;...
                                                                phi_n*phi_p*vlm   -phi_n*phi_p*vlPrime_mPrime];
                                                        else % Ng is 4
                                                            p1 = i141;
                                                            p2 = i142;
                                                            p3 = i143;
                                                            phi_p1 = phi(p1);
                                                            phi_p2 = phi(p2);
                                                            phi_p3 = phi(p3);
                                                            % Codebook for 2-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-4
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(2*Pcsirs))*[vlm                  vlPrime_mPrime;...
                                                                phi_n*vlm           -phi_n*vlPrime_mPrime;...
                                                                phi_p1*vlm           phi_p1*vlPrime_mPrime;...
                                                                phi_n*phi_p1*vlm    -phi_n*phi_p1*vlPrime_mPrime
                                                                phi_p2*vlm           phi_p2*vlPrime_mPrime;...
                                                                phi_n*phi_p2*vlm    -phi_n*phi_p2*vlPrime_mPrime;...
                                                                phi_p3*vlm           phi_p3*vlPrime_mPrime;...
                                                                phi_n*phi_p3*vlm    -phi_n*phi_p3*vlPrime_mPrime];
                                                        end
                                                    else % Codebook mode is 2
                                                        n0 = i20;
                                                        phi_n0 = phi(n0);
                                                        n1 = i21;
                                                        bn1 = b(n1);
                                                        n2 = i22;
                                                        bn2 = b(n2);
                                                        p1 = i141;
                                                        ap1 = a(p1);
                                                        p2 = i142;
                                                        ap2 = a(p2);
                                                        % Codebook for 2-layer CSI
                                                        % reporting using antenna ports
                                                        % 3000 to 2999+P_CSIRS, as
                                                        % defined in TS 38.214 Table
                                                        % 5.2.2.2.2-4
                                                        codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(2*Pcsirs))*[vlm             vlPrime_mPrime;...
                                                            phi_n0*vlm     -phi_n0*vlPrime_mPrime;...
                                                            ap1*bn1*vlm     ap1*bn1*vlPrime_mPrime;...
                                                            ap2*bn2*vlm    -ap2*bn2*vlPrime_mPrime];
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        case {3,4} % Number of layers is 3 or 4
            % Compute i13 parameter range, corresponding k1 and k2,
            % according to TS 38.214 Table 5.2.2.2.2-2
            if (N1 == 2) && (N2 == 1)
                i13_length = 1;
                k1 = O1;
                k2 = 0;
            elseif (N1 == 4) && (N2 == 1)
                i13_length = 3;
                k1 = O1*(1:3);
                k2 = [0 0 0];
            elseif (N1 == 8) && (N2 == 1)
                i13_length = 4;
                k1 = O1*(1:4);
                k2 = [0 0 0 0];
            elseif (N1 == 2) && (N2 == 2)
                i13_length = 3;
                k1 = [O1 0 O1];
                k2 = [0 O2 O2];
            elseif (N1 == 4) && (N2 == 2)
                i13_length = 4;
                k1 = [O1 0 O1 2*O1];
                k2 = [0 O2 O2 0];
            end
            codebook = zeros(Pcsirs,nLayers,i20_length,i21_length,i22_length,i11_length,i12_length,i13_length,i141_length,i142_length,i143_length);
            % Loop over all the values of all the indices
            for i11 = 0:i11_length-1
                for i12 = 0:i12_length-1
                    for i13 = 0:i13_length-1
                        l = i11;
                        m = i12;
                        lPrime = i11 + k1(i13+1);
                        mPrime = i12 + k2(i13+1);
                        bitIndex = N2*O2*l+m;
                        lmRestricted = isRestricted(reportConfig.CodebookSubsetRestriction,bitIndex,[],reportConfig.i2Restriction);
                        if ~(lmRestricted)
                            vlm = getVlm(N1,N2,O1,O2,l,m);
                            vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                            for i141 = 0:i141_length-1
                                for i142 = 0:i142_length-1
                                    for i143 = 0:i143_length-1
                                        for i20 = 0:i20_length-1
                                            for i21 = 0:i21_length-1
                                                for i22 = 0:i22_length-1
                                                    if reportConfig.CodebookMode == 1
                                                        n = i20;
                                                        phi_n = phi(n);
                                                        if Ng == 2
                                                            p = i141;
                                                            phi_p = phi(p);
                                                            if nLayers == 3
                                                                % Codebook for 3-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-5
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(3*Pcsirs))*[vlm                vlPrime_mPrime                 vlm;...
                                                                    phi_n*vlm          phi_n*vlPrime_mPrime          -phi_n*vlm;...
                                                                    phi_p*vlm          phi_p*vlPrime_mPrime           phi_p*vlm;...
                                                                    phi_n*phi_p*vlm    phi_n*phi_p*vlPrime_mPrime    -phi_n*phi_p*vlm];
                                                            elseif nLayers == 4
                                                                % Codebook for 4-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-6
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(4*Pcsirs))*[vlm                vlPrime_mPrime                 vlm                 vlPrime_mPrime;...
                                                                    phi_n*vlm          phi_n*vlPrime_mPrime          -phi_n*vlm          -phi_n*vlPrime_mPrime;...
                                                                    phi_p*vlm          phi_p*vlPrime_mPrime           phi_p*vlm           phi_p*vlPrime_mPrime;...
                                                                    phi_n*phi_p*vlm    phi_n*phi_p*vlPrime_mPrime    -phi_n*phi_p*vlm    -phi_n*phi_p*vlPrime_mPrime];
                                                            end
                                                        else % Ng is 4
                                                            p1 = i141;
                                                            p2 = i142;
                                                            p3 = i143;
                                                            phi_p1 = phi(p1);
                                                            phi_p2 = phi(p2);
                                                            phi_p3 = phi(p3);
                                                            if nLayers == 3
                                                                % Codebook for 3-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-5
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(3*Pcsirs))*[vlm                 vlPrime_mPrime                  vlm;...
                                                                    phi_n*vlm           phi_n*vlPrime_mPrime           -phi_n*vlm;...
                                                                    phi_p1*vlm          phi_p1*vlPrime_mPrime           phi_p1*vlm;...
                                                                    phi_n*phi_p1*vlm    phi_n*phi_p1*vlPrime_mPrime    -phi_n*phi_p1*vlm
                                                                    phi_p2*vlm          phi_p2*vlPrime_mPrime           phi_p2*vlm;...
                                                                    phi_n*phi_p2*vlm    phi_n*phi_p2*vlPrime_mPrime    -phi_n*phi_p2*vlm;...
                                                                    phi_p3*vlm          phi_p3*vlPrime_mPrime           phi_p3*vlm;...
                                                                    phi_n*phi_p3*vlm    phi_n*phi_p3*vlPrime_mPrime    -phi_n*phi_p3*vlm];
                                                            elseif nLayers == 4
                                                                % Codebook for 4-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-6
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(4*Pcsirs))*[vlm                 vlPrime_mPrime                  vlm                  vlPrime_mPrime;...
                                                                    phi_n*vlm           phi_n*vlPrime_mPrime           -phi_n*vlm           -phi_n*vlPrime_mPrime;...
                                                                    phi_p1*vlm          phi_p1*vlPrime_mPrime           phi_p1*vlm           phi_p1*vlPrime_mPrime;...
                                                                    phi_n*phi_p1*vlm    phi_n*phi_p1*vlPrime_mPrime    -phi_n*phi_p1*vlm    -phi_n*phi_p1*vlPrime_mPrime
                                                                    phi_p2*vlm          phi_p2*vlPrime_mPrime           phi_p2*vlm           phi_p2*vlPrime_mPrime
                                                                    phi_n*phi_p2*vlm    phi_n*phi_p2*vlPrime_mPrime    -phi_n*phi_p2*vlm    -phi_n*phi_p2*vlPrime_mPrime
                                                                    phi_p3*vlm          phi_p3*vlPrime_mPrime           phi_p3*vlm           phi_p3*vlPrime_mPrime
                                                                    phi_n*phi_p3*vlm    phi_n*phi_p3*vlPrime_mPrime    -phi_n*phi_p3*vlm    -phi_n*phi_p3*vlPrime_mPrime];

                                                            end
                                                        end
                                                    else % Codebook mode is 2
                                                        n0 = i20;
                                                        phi_n0 = phi(n0);
                                                        n1 = i21;
                                                        bn1 = b(n1);
                                                        n2 = i22;
                                                        bn2 = b(n2);
                                                        p1 = i141;
                                                        ap1 = a(p1);
                                                        p2 = i142;
                                                        ap2 = a(p2);
                                                        if nLayers == 3
                                                            % Codebook for 3-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-5
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(3*Pcsirs))*[vlm            vlPrime_mPrime           vlm;...
                                                                phi_n0*vlm     phi_n0*vlPrime_mPrime   -phi_n0*vlm;...
                                                                ap1*bn1*vlm    ap1*bn1*vlPrime_mPrime   ap1*bn1*vlm;...
                                                                ap2*bn2*vlm    ap2*bn2*vlPrime_mPrime  -ap2*bn2*vlm];
                                                        elseif nLayers == 4
                                                            % Codebook for 4-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-6
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(4*Pcsirs))*[vlm            vlPrime_mPrime            vlm            vlPrime_mPrime;...
                                                                phi_n0*vlm     phi_n0*vlPrime_mPrime    -phi_n0*vlm    -phi_n0*vlPrime_mPrime;
                                                                ap1*bn1*vlm    ap1*bn1*vlPrime_mPrime    ap1*bn1*vlm    ap1*bn1*vlPrime_mPrime;
                                                                ap2*bn2*vlm    ap2*bn2*vlPrime_mPrime   -ap2*bn2*vlm   -ap2*bn2*vlPrime_mPrime];
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
    end
end

function [H_bwp,csirsIndBWP_k,csirsIndBWP_l,csirsIndBWP_p] = getCSIRSIndicesAndHInBWP(carrier,reportConfig,H,csirsIndSubs)
%   [H_bwp,csirsIndBWP_k,csirsIndBWP_l] = getCSIRSIndicesAndHInBWP(carrier,reportConfig,H,csirsIndSubs)
%   returns the CSI-RS indices in subscript form with in the BWP

    % Calculate the start of BWP relative to the carrier
    bwpStart = reportConfig.NStartBWP - carrier.NStartGrid;

    % Rearrange the channel matrix dimensions from
    % K-by-L-by-nRxAnts-by-Pcsirs to nRxAnts-by-Pcsirs-by-K-by-L
    H = permute(H,[3,4,1,2]); % w.r.t. carrier
    H_bwp = H(:,:,bwpStart*12 + 1: (bwpStart + reportConfig.NSizeBWP)*12,:); % w.r.t. BWP

    % Consider only the RE indices corresponding to the first CSI-RS port
    csirsIndBWP_kTemp = csirsIndSubs(:,1);
    csirsIndBWP_lTemp = csirsIndSubs(:,2);

    % Extract the CSI-RS indices which are present in the BWP
    indInBWP = (csirsIndBWP_kTemp >= bwpStart*12 + 1) & csirsIndBWP_kTemp <= (bwpStart + reportConfig.NSizeBWP)*12;
    csirsIndBWP_k = csirsIndBWP_kTemp(indInBWP);
    csirsIndBWP_l = csirsIndBWP_lTemp(indInBWP);

    % Make the CSI-RS subscripts relative to BWP
    csirsIndBWP_k = csirsIndBWP_k - bwpStart*12;
    csirsIndBWP_p = ones(size(csirsIndBWP_k)); % we consider only first CSI-RS port
end

function [PMINaNSet,nanInfo] = getPMINaNSet(carrier,reportConfig,subbandInfo,codebook,indexSetSizes,numCSIRSPorts,nLayers,csirsIndBWP_k)
%   [PMINaNSet,nanInfo] = getPMINaNSet(carrier,reportConfig,subbandInfo,codebook,indexSetSizes,numCSIRSPorts,nLayers)
%   returns the PMI set and PMI information as NaNs.

    % Set the below flags to identify the codebook type
    isType1SinglePanel = strcmpi(reportConfig.CodebookType,'Type1SinglePanel');
    isType1MultiPanel = strcmpi(reportConfig.CodebookType,'Type1MultiPanel');
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');
    isEnhType2 = strcmpi(reportConfig.CodebookType,'eType2');
    csirsIndLen = length(csirsIndBWP_k);
    nanInfo.CSIRSIndices = NaN(csirsIndLen,3);

    % Generate PMI set and output information structure with NaNs
    if isType2
        numI1Indices = 3 + (1 + 2*reportConfig.NumberOfBeams)*nLayers;
        numI2Columns = nLayers*(1+reportConfig.SubbandAmplitude);
        numI2Rows = 2*reportConfig.NumberOfBeams;
        PMINaNSet.i1 = NaN(1,numI1Indices);
        PMINaNSet.i2 = NaN(numI2Rows,numI2Columns,subbandInfo.NumSubbands);
        nanInfo.SINRPerRE = [];
        nanInfo.SINRPerREPMI = [];
        nanInfo.SINRPerSubband = NaN(subbandInfo.NumSubbands,nLayers);
        nanInfo.Codebook = [];
        nanInfo.W = NaN(numCSIRSPorts,nLayers,subbandInfo.NumSubbands);
    elseif isEnhType2
        Mv = ceil(reportConfig.pv*subbandInfo.NumSubbands/reportConfig.NumberOfPMISubbandsPerCQISubband);
        numI1Indices = 4 + (1 + 2*reportConfig.NumberOfBeams*Mv + 1)*nLayers;
        numI2Values = nLayers*(2 + 2*reportConfig.NumberOfBeams*Mv + 2*reportConfig.NumberOfBeams*Mv);
        PMINaNSet.i1 = NaN(1,numI1Indices);
        PMINaNSet.i2 = NaN(1,numI2Values,subbandInfo.NumSubbands);
        nanInfo.SINRPerRE = [];
        nanInfo.SINRPerREPMI = [];
        nanInfo.SINRPerSubband = NaN(subbandInfo.NumSubbands,nLayers);
        nanInfo.Codebook = [];
        nanInfo.W = NaN(numCSIRSPorts,nLayers,subbandInfo.NumSubbands);
    else
        if isType1SinglePanel
            PMINaNSet.i1 = NaN(1,3);
            PMINaNSet.i2 = NaN(1,subbandInfo.NumSubbands);
        elseif isType1MultiPanel
            PMINaNSet.i1 = NaN(1,6);
            PMINaNSet.i2 = NaN(3,subbandInfo.NumSubbands);
        end
        nanInfo.SINRPerRE = NaN([csirsIndLen,nLayers,indexSetSizes]);
        nanInfo.SINRPerREPMI = NaN(csirsIndLen,nLayers);
        nanInfo.SINRPerSubband = NaN(subbandInfo.NumSubbands,nLayers);
        nanInfo.Codebook = codebook;
        nanInfo.W = NaN(numCSIRSPorts,nLayers);
    end
end

function [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIPMIWideband(reportConfig,SINRPerRE,codebook,indexSetSizes)
%   [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIPMIWideband(reportConfig,SINRPerRE,codebook,indexSetSizes)
%   returns the PMI set for type I single panel and multipanel codebooks
%   along with reported precoding matrix and SINR information

    % Sum of SINRs across the BWP for all layers for each PMI index
    totalSINR = squeeze(sum(SINRPerRE,[1 2]));
    % Round the total SINR value to four decimals, to avoid the
    % fluctuations in the PMI output because of the minute
    % variations among the SINR values corresponding to different
    % PMI indices
    totalSINR = round(reshape(totalSINR,indexSetSizes),4,'decimals');
    % Find the set of indices that correspond to the precoding
    % matrix with maximum SINR
    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        [i2,i11,i12,i13] = ind2sub(size(totalSINR),find(totalSINR == max(totalSINR,[],'all'),1));
        PMISet.i1 = [i11 i12 i13];
        PMISet.i2 = i2;
        W = codebook(:,:,i2,i11,i12,i13);
        SINRPerREPMI = SINRPerRE(:,:,i2,i11,i12,i13);
    elseif strcmpi(reportConfig.CodebookType,'Type1MultiPanel')
        [i20,i21,i22,i11,i12,i13,i141,i142,i143] = ind2sub(size(totalSINR),find(totalSINR == max(totalSINR,[],'all'),1));
        PMISet.i1 = [i11 i12 i13 i141 i142 i143];
        PMISet.i2 = [i20; i21; i22];
        W = codebook(:,:,i20,i21,i22,i11,i12,i13,i141,i142,i143);
        SINRPerREPMI = SINRPerRE(:,:,i20,i21,i22,i11,i12,i13,i141,i142,i143);
    end
    SubbandSINRs = mean(SINRPerRE,1);

end

function [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIPMISubband(carrier,reportConfig,codebook,PMISet,SINRPerRE,subbandInfo,indexSetSizes,csirsIndSubs_k,csirsIndSubs_l)
%   [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIPMISubband(carrier,reportConfig,codebook,PMISet,SINRPerRE,subbandInfo,indexSetSizes,csirsIndSubs_k,csirsIndSubs_l)
%   returns the PMI set for type I codebooks in case of subband mode

    numSubbands = subbandInfo.NumSubbands;
    numCSIRSPorts = size(codebook,1);
    nLayers = size(codebook,2);
    W = zeros(numCSIRSPorts,nLayers,numSubbands);
    SINRPerREPMI = zeros([length(csirsIndSubs_k),nLayers]);
    SubbandSINRs = NaN([numSubbands,nLayers,indexSetSizes]);

    % Consider the starting position of the first subband as 0, which
    % is the start of BWP
    subbandStart = 0;
    % Loop over all the subbands
    for SubbandIdx = 1:numSubbands
        % Extract the SINR values in the subband
        subbandInd = (csirsIndSubs_k>subbandStart*12) & (csirsIndSubs_k<(subbandStart+ subbandInfo.SubbandSizes(SubbandIdx))*12+1);
        sinrValuesPerSubband = SINRPerRE(subbandInd,:,:,:,:,:,:,:,:,:,:,:);
        if all(isnan(sinrValuesPerSubband(:))) % CSI-RS is absent in the subband
            % Report i2 as NaN for the current subband as CSI-RS is not
            % present
            PMISet.i2(:,SubbandIdx) = NaN;
        else % CSI-RS is present in the subband
            % Average the SINR per RE values across the subband for all
            % the PMI indices
            SubbandSINRs(SubbandIdx,:,:,:,:,:,:,:,:) = mean(SINRPerRE(subbandInd,:,:,:,:,:,:,:,:),1);
            % Add the subband SINR values across all the layers for
            % each PMI i2 index set.
            i11_WB = PMISet.i1(1);
            i12_WB = PMISet.i1(2);
            i13_WB = PMISet.i1(3);
            if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
                tempSubbandSINR = round(sum(SubbandSINRs(SubbandIdx,:,:,i11_WB,i12_WB,i13_WB),2),4,'decimals');
                % Report i2 index corresponding to the maximum SINR for
                % current subband
                [~,PMISet.i2(SubbandIdx)] = max(tempSubbandSINR);
                W(:,:,SubbandIdx) = codebook(:,:,PMISet.i2(SubbandIdx),i11_WB,i12_WB,i13_WB);
                SINRPerREPMI(subbandInd,:) = SINRPerRE(subbandInd,:,PMISet.i2(SubbandIdx),i11_WB,i12_WB,i13_WB);
            elseif strcmpi(reportConfig.CodebookType,'Type1MultiPanel')
                i141_WB = PMISet.i1(4);
                i142_WB = PMISet.i1(5);
                i143_WB = PMISet.i1(6);
                tempSubbandSINR = round(sum(SubbandSINRs(SubbandIdx,:,:,:,:,i11_WB,i12_WB,i13_WB,i141_WB,i142_WB,i143_WB),2),4,'decimals');
                % Report i2 indices set [i20; i21; i22] corresponding
                % to the maximum SINR for current subband
                [i20,i21,i22] = ind2sub(size(squeeze(tempSubbandSINR)),find(tempSubbandSINR == max(tempSubbandSINR,[],'all'),1));
                PMISet.i2(:,SubbandIdx) = [i20;i21;i22];
                W(:,:,SubbandIdx) = codebook(:,:,i20,i21,i22,i11_WB,i12_WB,i13_WB,i141_WB,i142_WB,i143_WB);
                SINRPerREPMI(subbandInd,:) = SINRPerRE(subbandInd,:,i20,i21,i22,i11_WB,i12_WB,i13_WB,i141_WB,i142_WB,i143_WB);
            end
        end
        % Compute the starting position of next subband
        subbandStart = subbandStart + subbandInfo.SubbandSizes(SubbandIdx);
    end
end

function [W,PMISet,SINR,wbInfo] = getTypeIIPMIWideband(reportConfig,H,nLayers,nVar,PMINaNSet)
%   [W,PMISet,SINR,wbInfo] = getTypeIIPMIWideband(reportConfig,H,nLayers,nVar,PMINaNSet)
%   computes the wideband precoding matrix and its index set for type II
%   and enhanced type II codebooks

    % Extract the report configuration parameters
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');
    N1 = reportConfig.PanelDimensions(1);
    N2 = reportConfig.PanelDimensions(2);
    O1 = reportConfig.OverSamplingFactors(1);
    O2 = reportConfig.OverSamplingFactors(2);
    nPSK = reportConfig.PhaseAlphabetSize;
    numBeams = reportConfig.NumberOfBeams;

    % Get the channel Eigenvector
    HH = pagemtimes(H,'ctranspose',H,'none');
    [~,~,V] = pagesvd(HH);
    V_avg = mean(V,3);
    EigenVectors = V_avg(:,1:nLayers,:);

    % Get the m1 and m2 indices for all beam combinations
    [m1Set,m2Set] = getm1m2Index(N1,N2,O1,O2,numBeams);
    numBeamCombinations = size(m1Set,1);
    
    % Obtain maximum allowable amplitudes from the codebook subset restriction
    % as defined in TS 38.214 Table 5.2.2.2.3-6
    maximumAmplitudes = ones(2*numBeams,numBeamCombinations,O1,O2);
    maxAllowableAmpWithIndex = codebookSubsetRestrictionXType2(reportConfig.CodebookSubsetRestriction,reportConfig.PanelDimensions);

    % Initialize variables
    numRE = size(H,3);
    SINRValues = NaN(numRE,nLayers,numBeamCombinations,O1,O2);
    Precoders = NaN(2*N1*N2,nLayers,numBeamCombinations,O1,O2); 

    % loop over all beam groups
    for i12Val = 1:numBeamCombinations
        for q1Val = 1:O1
            for q2Val = 1:O2
                m1 = m1Set(i12Val,:,q1Val);
                m2 = m2Set(i12Val,:,q2Val);
                W1 = getW1(N1,N2,O1,O2,m1,m2);          % Of size 2*N1*N2-by-2*numBeams
                W2 = (W1'*EigenVectors)./(N1*N2);       % EigenVectors = W1*W2;
                                                        % W2 = (W1'*EigenVectors)./(N1*N2), as W1'*W1 = (N1*N2)*eye(2*numBeams)
                                                        % It is of size 2*numBeams-by-nLayers-by-N3
                % Get the maximum possible amplitude for each beam in the
                % orthogonal beam group considering the codebook subset
                % restriction
                maxAmplitudesPerPol = ones(numBeams,1);
                beamIndices = logical(sum(maxAllowableAmpWithIndex(:,1) == m1 & maxAllowableAmpWithIndex(:,2) == m2,1));
                maxAmpIndices = logical(sum(maxAllowableAmpWithIndex(:,1) == m1 & maxAllowableAmpWithIndex(:,2) == m2,2));
                maxAmplitudesPerPol(beamIndices) = maxAllowableAmpWithIndex(maxAmpIndices,3);
                maximumAmplitudes(:,i12Val,q1Val,q2Val) = [maxAmplitudesPerPol;maxAmplitudesPerPol];

                % Wideband, only quantization is considered
                if isType2 % Type II codebooks
                    % Quantization of beam combining coefficients
                    [W2_quantized,amplitudesQuantized] = quantizeW2ForType2Wideband(W2,nPSK,maximumAmplitudes(:,i12Val,q1Val,q2Val));
                    % Compute the multiplication factor
                    multFact = 1./sqrt(nLayers*N1*N2.*sum(amplitudesQuantized.^2));
                else % Enhanced type II codebooks                    
                    W2 = permute(W2,[1 3 2]);
                    beta = reportConfig.beta;
                    % Quantization of beam combining coefficients
                    W2_quantized = quantizeW2ForEnhancedType2(W2,beta,maximumAmplitudes(:,i12Val,q1Val,q2Val));
                    % Compute the multiplication factor
                    multFact = 1./sqrt(nLayers*(N1*N2).*sum(abs(W2_quantized).^2,1));
                end
                WTemp = reshape(multFact.*(pagemtimes(W1,W2_quantized)),2*N1*N2,nLayers); % Of size 2N1N2-by-nLayers
                Precoders(:,:,i12Val,q1Val,q2Val) = WTemp;
                if ~(any(isnan(WTemp),'all') || any(isinf(WTemp),'all'))
                    SINRValues(:,:,i12Val,q1Val,q2Val) = hPrecodedSINR(H,nVar,WTemp);
                end
            end
        end
    end
    if ~(all(isnan(SINRValues(:))))
        % Find the beam group with maximum SINR
        [~,cbidx] = max(mean(SINRValues,1:2),[],3:5,'linear');
        [i12,q1,q2] = ind2sub([numBeamCombinations O1 O2],cbidx);
        SINR = mean(SINRValues(:,:,i12,q1,q2),1); % Of size 1-by-nLayers

        % Compute W1 and W2 matrices for the selected beam group
        m1 = m1Set(i12,:,q1);
        m2 = m2Set(i12,:,q2);
        W1 = getW1(N1,N2,O1,O2,m1,m2);
        W2 = (W1'*EigenVectors);

        % Extract the precoding matrix
        W = Precoders(:,:,i12,q1,q2);

        % Output the required information
        wbInfo.W1 = W1;
        wbInfo.restictedAmps = maximumAmplitudes(:,i12,q1,q2);
        if isType2
            % Quantization of beam combining coefficients
            [~,amplitudesQuantized,amplitudesAbsolute,strBeamIdices,phi] = quantizeW2ForType2Wideband(W2,nPSK,wbInfo.restictedAmps);
            % Get the strongest beam index for each layer
            i13Set = mod(strBeamIdices'-1,2*numBeams)+1;
            i14l = mapPToKVals(amplitudesQuantized)'; % It is of size nLayers-by-totBeams
            i13_i14Set = [i13Set i14l]'; % It is of totBeams+1-by-nLayers
            PMISet.i1 = [q1 q2 i12 i13_i14Set(:)'];
            PMISet.i2 = phi;
            % Return the absolute wideband amplitudes. This information is
            % required to exclude the wideband amplitudes, in case of
            % subband mode
            wbInfo.WBAmpsAbsolute = amplitudesAbsolute;
            % Return the quantized wideband amplitudes. This information is
            % required to calculate the overall quantized amplitudes, in
            % case of subband mode. It is of size totBeams-by-nLayers
            wbInfo.WBAmpsQuantized = amplitudesQuantized;
        else % Enhanced type II codebook
            W2 = permute(W2,[1 3 2]);
            beta = reportConfig.beta;
            % Quantization of beam combining coefficients
            [~,k1,k2,phi,istar,fstar] = quantizeW2ForEnhancedType2(W2,beta,wbInfo.restictedAmps);
            [i1,i2] = eType2Indices_afterRemapping(1,1,q1,q2,i12,k1,k2,phi,istar,fstar,0,zeros(1,nLayers));
            PMISet.i1 = i1;
            PMISet.i2 = i2;
            wbInfo.istar = istar;
        end
    else
        PMISet = PMINaNSet;
        W = NaN(2*N1*N2,nLayers);
        SINR = NaN;
        if isType2
            wbInfo.WBAmpsAbsolute = zeros(2*numBeams,nLayers);
        else
            wbInfo.WBAmpsAbsolute = zeros(2,nLayers);
        end
        wbInfo.W1 = NaN(2*N1*N2,2*numBeams);
        wbInfo.istar = zeros(nLayers,1);
        wbInfo.WBAmpsQuantized = zeros(2*numBeams,nLayers);
        wbInfo.restictedAmps = zeros(2*numBeams,1);
    end
end

function [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIIPMISubband(reportConfig,H_bwp,nVar,nLayers,csirsIndBWP_k,csirsIndBWP_l,WidebandPMI,wbInfo,subbandInfo,indexSetSizes)
%   [PMISet,W,SINRPerREPMI,SubbandSINRs] = getTypeIIPMISubband(reportConfig,H_bwp,nVar,nLayers,csirsIndBWP_k,csirsIndBWP_l,WidebandPMI,wbInfo,subbandInfo,indexSetSizes)
%   computes the subband precoding matrices and their index set for type II
%   and enhanced type II codebooks. The function also returns SINR related
%   information

    % Get the report configuration parameters
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');
    N1 = reportConfig.PanelDimensions(1);
    N2 = reportConfig.PanelDimensions(2);
    nPSK = reportConfig.PhaseAlphabetSize;
    numBeams = reportConfig.NumberOfBeams;

    % Get W1 matrix and restricted amplitudes information
    W1 = wbInfo.W1;
    restictedAmps = wbInfo.restictedAmps;

    % Get the eigenvectors for all subbands
    if isType2
        isSubbandAmplitude = reportConfig.SubbandAmplitude;
    end
    EigVector = getSubbandChannelEigenvectors(H_bwp,subbandInfo,csirsIndBWP_k,csirsIndBWP_l);
    if isType2
        % For type II codebooks, update the eigenvectors to all NaNs for
        % the subbands in which CSI-RS is not present
        invalidSBs = reshape(sum(EigVector,[1 2]),1,[]) == 0;
        EigVector(:,:,invalidSBs) = NaN;
    end
    Ev = EigVector(:,1:nLayers,:);

    % Compute the beam combining coefficients matrix for all subbands
    W2 = pagemtimes(W1,'ctranspose',Ev,'none')./(N1*N2); % Ev = W1*W2; W2 = (W1'*Ev)./(N1*N2), as W1'*W1 = (N1*N2)*eye(2*numBeams)
                                                         % It is of size 2*numBeams-by-nLayers-by-N3
    N3 = size(W2,3);    
    if isType2
        % Quantization of beam combining coefficients
        WBAmpsAbsolute = wbInfo.WBAmpsAbsolute;
        WBAmpsQuantized = wbInfo.WBAmpsQuantized;
        [W2_quantized,amplitudeQuantized,amplitudeSBQuantized,c] = quantizeW2ForType2Subband(W2,WBAmpsAbsolute,WBAmpsQuantized,WidebandPMI,nPSK,isSubbandAmplitude,invalidSBs);

        % Compute precoding matrices for all subbands
        multFact = 1./sqrt(nLayers*N1*N2.*sum(amplitudeQuantized.^2));
        W = multFact.*pagemtimes(W1,'none',W2_quantized,'none');

        % Form i1 and i2 indices
        i13l = WidebandPMI.i1(4:2*numBeams+1:end);
        % Get the strongest beam index for each layer
        i14l(1,:) = WidebandPMI.i1(5:5+2*numBeams-1);
        if nLayers == 2
            i14l(2,:) = WidebandPMI.i1(end-2*numBeams+1:end);
        end
        i13_i14Set = [i13l' i14l]'; % It is of totBeams+1-by-nLayers
        PMISet.i1 = [WidebandPMI.i1(1:3) i13_i14Set(:)'];
        if isSubbandAmplitude
            i22l = NaN(size(amplitudeSBQuantized));
            for sbIdx = 1:size(amplitudeSBQuantized,3)
                for layerIdx = 1:nLayers
                    sbQuanTemp = amplitudeSBQuantized(:,layerIdx,sbIdx);
                    if ~all(isnan(sbQuanTemp))
                        i22l(:,layerIdx,sbIdx) = 1;
                        i22l(sbQuanTemp == 1,layerIdx,sbIdx) = 2; % 1-based indices
                    end
                end
            end
            numI2Cols = nLayers*(1+isSubbandAmplitude);
            i2Temp = [c i22l];
            PMISet.i2 = i2Temp(:,[(1:2:numI2Cols) (2:2:numI2Cols)],:);
        else
            PMISet.i2 = c;
        end
    else % Enhanced type II codebook
        % Get the number of DFT vectors used for DFT compression
        Mv = ceil(reportConfig.pv*N3/reportConfig.NumberOfPMISubbandsPerCQISubband);

        % DFT compression
        istar = wbInfo.istar;
        [W2Compressed,Minit,n3,Vm] = W2CompressionEnhancedType2(W2,nLayers,istar,Mv);

        % Quantization of beam combining coefficients
        beta = reportConfig.beta;
        [W2_quantized,k1,k2,c,istar,fstar] = quantizeW2ForEnhancedType2(W2Compressed,beta,restictedAmps);

        % Form W2 matrix of size 2*numBeams-by-N3-by-nLayers
        W2q = pagemtimes(W2_quantized,'none',Vm,'transpose');

        % Normalization factor of precoding matrix W
        gamma = sum(abs(W2q).^2,1);

        % Normalized precoding matrix for each subband and layer
        Wt = pagemtimes(W1,W2q)./sqrt(nLayers*gamma.*N1*N2);

        % Reshape W to [2*N1*N2 nLayers N3] array
        W = permute(Wt,[1 3 2]);

        % Form PMI indices
        [i1,i2] = eType2Indices_afterRemapping(N3,Mv,WidebandPMI.i1(1),WidebandPMI.i1(2),WidebandPMI.i1(3),k1,k2,c,istar,fstar,Minit,n3);
        PMISet.i1 = i1;
        PMISet.i2 = i2;
    end

    SubbandSINRs = NaN([N3,nLayers,indexSetSizes]);
    SINRPerREPMI = zeros([length(csirsIndBWP_k),nLayers]);
    if ~(all(isnan(PMISet.i1)) && all(isnan(PMISet.i2(:))))
        % Consider the starting position of the first subband as 0, which
        % is the start of BWP
        subbandStart = 0;
        % Loop over all the subbands
        for SubbandIdx = 1:N3
            % Extract the SINR values in the subband
            kRangeSB = (subbandStart*12 + 1):(subbandStart+ subbandInfo.SubbandSizes(SubbandIdx))*12;
            csirsSBInd = find(csirsIndBWP_k >= kRangeSB(1) & csirsIndBWP_k <= kRangeSB(end));
            if ~isempty(csirsSBInd)
                Wsubband = W(:,:,SubbandIdx);
                csirs_sb_k = csirsIndBWP_k(csirsSBInd);
                csirs_sb_l = csirsIndBWP_l(csirsSBInd);
                Hcsirs_sb = H_bwp(:,:,csirs_sb_k+(csirs_sb_l-1)*size(H_bwp,3));
                SINRPerRE_SB = computeSINRPerRE(Hcsirs_sb,Wsubband,nVar,csirs_sb_k,indexSetSizes);
                SINRPerREPMI(csirsSBInd,:) = SINRPerRE_SB(:,:,:);
                SubbandSINRs(SubbandIdx,:) = mean(SINRPerRE_SB,[1 2]);
            end
            % Compute the starting position of next subband
            subbandStart = subbandStart + subbandInfo.SubbandSizes(SubbandIdx);
        end
    end
end

function [W2_quantized,amplitudeQuantized_p1,amplitudes,strongBeamIdices_i13l,c] = quantizeW2ForType2Wideband(W2,nPSK,maximumAmplitudes)
%   [W2_quantized,amplitudeQuantized_p1,amplitudes,strongBeamIdices_i13l,c] = quantizeW2ForType2Wideband(W2,nPSK,maximumAmplitudes)
%   quantizes the W2 matrix in case of type II codebooks

    numBeams = size(W2,1)/2;
    nLayers = size(W2,2);

    % Quantize amplitudes
    [theta,amplitudes] = cart2pol(real(W2),imag(W2)); % Each output is of size 2*numBeams-by-nLayers
    [~,strongestBeamIdx] = max(amplitudes,[],1,'linear'); % Strongest beam index across both the polarizations
    strongBeamIdices_i13l = strongestBeamIdx; % For all the layers
    amplitudeNormalized = amplitudes./amplitudes(strongestBeamIdx);
    amplitudeQuantized_p1 = zeros(2*numBeams,1);
    for layerIdx = 1:nLayers
        for beamIdx = 1:2*numBeams
            amplitudeQuantized_p1(beamIdx,layerIdx) = quantizeAmplitudesP1Rel15(amplitudeNormalized(beamIdx,layerIdx),maximumAmplitudes(beamIdx,1));
        end
    end

    % Quantize phases
    thetaNormalized = theta - theta(strongestBeamIdx);
    c = mod(round(thetaNormalized*nPSK/(2*pi)),nPSK);
    phiVals = exp(1i*2*pi*c/nPSK);

    % Form beam combining coefficients matrix
    W2_quantized = amplitudeQuantized_p1.*phiVals;
end

function [W2_quantized,amplitudeQuantized_p1p2,amplitudeSBQuantized_p2,c] = quantizeW2ForType2Subband(W2,WBAmpsAbsolute,WBAmpsQuantized_p1,WidebandPMI,nPSK,sbAmpFlag,invalidSBs)
%   [W2_quantized,amplitudeQuantized,amplitudeSBQuantized,c] = quantizeW2ForType2Subband(W2,WBAmpsAbsolute,WBAmpsQuantized_p1,WidebandPMI,nPSK,sbAmpFlag,invalidSBs)
%   quantizes the W2 matrices for all subbands in case of type II codebooks

    % W2 is if size 2*numBeams-by-nLayers-by-N3
    numBeams = size(W2,1)/2;
    nLayers = size(W2,2);
    N3 = size(W2,3);
    [theta,amplitude] = cart2pol(real(W2),imag(W2));
    % Remove the wideband amplitude portion
    W2Subband_p2 = amplitude./repmat(WBAmpsAbsolute,1,1,N3); % It is of size 2*numBeams-by-nLayers-by-N3

    % Get the i13 indices for subband amplitudes normalization
    i13l = WidebandPMI.i1(4:2*numBeams+1:end);
    % Get the indices in the linear form
    i13l_linear = i13l + (0:nLayers-1)*2*numBeams;

    % To make the subband amplitude corresponds to i13 index as 1
    W2Normalized = W2Subband_p2./reshape(W2Subband_p2(i13l_linear' + 2*numBeams*nLayers*(0:N3-1)),1,nLayers,N3); % 2*numBeams-by-nLayers-by-N3

    % Quantize subband amplitudes
    stdSBAmps = [1/sqrt(2);1];
    amplitudeSBQuantized_p2 = NaN(2*numBeams,nLayers,N3);
    for layerIdx = 1:nLayers
        for sbIdx = 1:N3
            W2Temp = W2Normalized(:,layerIdx,sbIdx);
            if any(W2Temp,'all')
                [~,minErrIdices] = min(abs(W2Temp-stdSBAmps'),[],2);
                amplitudeSBQuantized_p2(:,layerIdx,sbIdx) = stdSBAmps(minErrIdices);
            end
        end
    end

    % Get quantized phases
    thetaNormalized = theta - reshape(theta(i13l_linear' + 2*numBeams*nLayers*(0:N3-1)),1,nLayers,N3);
    c = mod(round(thetaNormalized*nPSK/(2*pi)),nPSK);

    % Update the subband amplitude and phase coefficients as per the
    % clauses mentioned in TS 38.214 Section 5.2.2.2.3
    Ml = WBAmpsQuantized_p1 > 0; % Logical array representing the non-zero wideband quantized amplitudes
    % Get the logical array representing the zero valued wideband amplitudes
    zeroWBAmpIndices = ~Ml;
    if sbAmpFlag % Subband amplitude is 'true'

        % Get the K2 value as per TS 38.214 Table 5.2.2.2.3-4
        K2 = 4 + 2*(numBeams == 4);
        % Number of non-zero coefficients for each layer
        nnzCoeffPerLayer = sum(Ml,1);
        [~,sortedIndWBCoeff] = sort(WBAmpsQuantized_p1,1,'descend');
        for layerIdx = 1:nLayers
            if nnzCoeffPerLayer(layerIdx) > K2
                %  -------------------------------- 
                %  |        |            |        |       Wideband coefficients
                %  --------------------------------
                %  <--K(2)-->                             Full resolution coefficients
                %  <----------Ml-------->                 Non-zero coefficients
                %  <------------ 2*numBeams ------>       Overall coefficients

                % - amplitudeSBQuantized_p2 values of K(2) portion are
                %   reported as is, excluding the strongest coefficient
                %   (which is already 1)
                % - amplitudeSBQuantized_p2 values in (2*numBeams)-K(2)
                %   portion are not reported and they are set to 1
                nonK2Ind_layer = sortedIndWBCoeff(K2+1:end,layerIdx);
                amplitudeSBQuantized_p2(nonK2Ind_layer,layerIdx,~invalidSBs) = 1;

                % - c values in K(2) portion are reported as is, excluding
                %   the strongest coefficient (which is already 0)
                % - c values in Ml-K(2) are reported with phase alphabet as
                %   4
                MlMinusK2Ind_layer = sortedIndWBCoeff(K2+1:nnzCoeffPerLayer(layerIdx),layerIdx);
                c(MlMinusK2Ind_layer,layerIdx,~invalidSBs) = mod(c(MlMinusK2Ind_layer,layerIdx,:),4);

                % - c values in (2*numBeams)-Ml portion are not reported
                %   and they are set to 0
                c(zeroWBAmpIndices(layerIdx),layerIdx,~invalidSBs) = 0;
            else
                %  -------------------------------- 
                %  |        |            |        |       Wideband coefficients
                %  --------------------------------
                %  <---Ml-->                              Non-zero coefficients
                %  <---------K(2)------->                 Full resolution coefficients
                %  <------------ 2*numBeams ------>       Overall coefficients

                for sbIdx = 1:N3
                    % Update the phase coefficients corresponding to the
                    % zero wideband amplitudes to 0
                    c(zeroWBAmpIndices(layerIdx),layerIdx,~invalidSBs(sbIdx)) = 0;
                    % Update the differential coefficients corresponding to
                    % the zero wideband amplitudes to 1
                    amplitudeSBQuantized_p2(zeroWBAmpIndices(layerIdx),layerIdx,~invalidSBs(sbIdx)) = 1;
                end
            end
        end

        % Get the overall quantized amplitudes
        amplitudeQuantized_p1p2 = WBAmpsQuantized_p1.*amplitudeSBQuantized_p2;
    else % Subband amplitude is 'false'

        for layerIdx = 1:nLayers
            for sbIdx = 1:N3
                % Update the phase coefficients corresponding to the zero
                % wideband amplitudes to 0
                c(zeroWBAmpIndices(layerIdx),layerIdx,~invalidSBs(sbIdx)) = 0;
            end
        end
        % Get the overall quantized amplitudes
        amplitudeQuantized_p1p2 = WBAmpsQuantized_p1;
    end

    phiVals = exp(1i*2*pi*c/nPSK);

    % Form beam combining coefficients matrix for all subbands
    W2_quantized = amplitudeQuantized_p1p2.*phiVals;
end

function [W2Compressed,Minit,n3,Vm] = W2CompressionEnhancedType2(W2,nLayers,istar,Mv)
%   [W2Compressed,Minit,n3,Vm] = W2CompressionEnhancedType2(W2,nLayers,istar,Mv)
%   performs the DFT compression for W2 matrix in case of enhanced type II
%   codebooks

    % Get the number of precoding matrices
    N3 = size(W2,3);

    % Phase preprocessing to improve FDD compression. For each layer, change
    % the phase reference of each subband of BCC W2 matrix to that of the
    % strongest beam in that layer. This improves the phase correlation
    % across subbands (R1-1906348)
    if N3 > 1
        for layerIdx = 1:nLayers
            phaseStrongBeams = angle(W2(istar(layerIdx),layerIdx,:));
            W2(:,layerIdx,:) = W2(:,layerIdx,:).*exp(-1i*phaseStrongBeams);
        end
    end

    % Generate N3 DFT basis vectors (y(t,l)^(f)) of length N3 each for FDD
    % compression. As per TS 38.214 Section 5.2.2.2.5, y(t,l)^(f) =
    % e^(j*2*pi*t*n3l/N3). This can be generated by taking the conjugate of
    % dftmtx function output.
    V = conj(dftmtx(N3));     % Of size N3-by-N3
    W2 = permute(W2,[1 3 2]); % Of size 2*numBeams-by-N3-by-nLayers

    % Project DFT bases V onto W2
    W2v = pagemtimes(W2,conj(V));

    % Select Mv DFT bases whose projections onto W2 which are stronger.
    % When the number of subbands N3 <= 19, all N3 bases are available for
    % selection of the Mv bases.
    % When N3 > 19, there is a set of windows of size 2*Mv from which Mv
    % DFT bases are selected. The position offset of the window, Minitial
    % is also determined.
    proj = sum(abs(W2v).^2,1);
    if N3 <= 19
        % Select the strongest Mv projections of the DFT bases onto W2 for
        % each layer. The DFT bases indices are stored in n3.
        [~,vInd] = sort(proj,2,'descend');
        n3 = permute(vInd(1,1:Mv,:),[2 3 1])-1;
        Minit = 0;
    else
        % Initialize the starting positions of all windows
        MinitRange = (-2*Mv+1:0)';
        % Get the indices of the DFT vectors in each window
        DFTVecIndices = (mod((MinitRange + N3)+(0:2*Mv-1),N3)); % 0-based indices, numberOfMInitValues-by-2*Mv
        % For each Minit value, there is a window with 2*Mv vectors
        projWin = reshape(proj(1,DFTVecIndices+1,:),[2*Mv 2*Mv nLayers]);
        % Sort 2*Mv projections from strong to weak for each Minit value to
        % select Mv vectors
        [sortedProj,sortedInd] = sort(projWin,2,'descend');
        % Get the index of Minit value which is having the maximum
        % projection across all layers, it is in the range 1...2*Mv,
        % 1-based index
        [~,i15] = max(sum(sortedProj(:,1:Mv,:),[2 3]));
        n3 = reshape(DFTVecIndices(i15,sortedInd(i15,1:Mv,:))',[],nLayers); % 0-based

        % Get Minit from i15 (1-based)
        Minit = MinitRange(i15); % Calculate Minit from i15
    end

    % Create Vm with the selected DFT bases
    Vm = zeros(N3,Mv,nLayers);
    Vm(:,:) = V(:,1+n3);

    % The codebook coefficients p1, p2, and c are quantized amplitudes
    % (p1,p2) and phases (c) from the projection of W2 on the selected
    % strong Mv DFT bases.
    W2Compressed = pagemtimes(W2,conj(Vm));
end

function [W2_quantized,k1,k2,c,istar,fstar] = quantizeW2ForEnhancedType2(W2,beta,maximumAvgAmplitudes)
%   [W2_quantized,k1,k2,c,istar,fstar] = quantizeW2ForEnhancedType2(W2,beta,maximumAvgAmplitudes)
%   quantizes the W2 matrix in case of enhanced type II codebooks

    numBeams = size(W2,1)/2;
    nLayers = size(W2,3);
    Mv = size(W2,2);
    nPSK = 16;
    [theta,amplitude] = cart2pol(real(W2),imag(W2)); % Each output is of size 2*numBeams-by-Mv-by-nLayers

    % Find the strongest beam in each layer
    [~,strongestBeamLayer] = max(amplitude.^2,[],[1 2],'linear');
    amplitudeNormalized = amplitude./amplitude(strongestBeamLayer); % It is of size 2*numBeams-by-Mv-by-nLayers

    % Indices f* of i24l and i* of k^(2)_(l,f*) which identify the
    % strongest coeff in layer l, i.e., the element k^(2)_(l,i*,f*).
    [istar,fstar,~] = ind2sub([2*numBeams Mv nLayers],strongestBeamLayer(:)); % 1-based indices, for each layer

    % Split amplitudes for different polarizations
    normalizedAmpPol0 = amplitudeNormalized(1:numBeams,:,:);            % It is of size numBeams-by-Mv-by-nLayers
    normalizedAmpPol1 = amplitudeNormalized(numBeams+(1:numBeams),:,:); % It is of size numBeams-by-Mv-by-nLayers

    % Find the strongest beam for each polarization before quantization
    maxAmpPol0 = max(normalizedAmpPol0,[],[1 2],'linear');
    maxAmpPol1 = max(normalizedAmpPol1,[],[1 2],'linear');

    % Normalize and quantize pol-wise amplitudes of each beam and freq.
    normalizedAmpPol0 = normalizedAmpPol0./maxAmpPol0; % It is of size numBeams-by-Mv-by-nLayers, for first polarization
    normalizedAmpPol1 = normalizedAmpPol1./maxAmpPol1; % It is of size numBeams-by-Mv-by-nLayers, for second polarization

    % Quantize overall polarization-wise amplitudes p^(1)_{l,0} and
    % p^(1)_{l,1}
    [p10,k10] = quantizeAmplitudesP1Rel16(maxAmpPol0,1);
    [p11,k11] = quantizeAmplitudesP1Rel16(maxAmpPol1,1);

    p1 = [p10;p11];                       % of size 2-by-1-by-nLayers, 2 rows for both the polarizations
    k1 = [k10;k11];                       % of size 2-by-1-by-nLayers, 2 rows for both the polarizations

    % Change reference point of phases to that of the strongest beam and
    % quantize to get phase coefficients c. This corresponds to index i25l.
    thn = theta - theta(strongestBeamLayer);
    c = mod(round(thn*nPSK/(2*pi)),nPSK);
    phase = 2*pi*c/nPSK;

    p2Amps = [normalizedAmpPol0;normalizedAmpPol1];
    bitmap = ones(2*numBeams,Mv,nLayers);
    if Mv > 1
        % Limit the number of amplitude (p2) and phase (c) coefficients per
        % layer to K0 = ceil(beta*2*numBeams*Mv). The weakest coefficients
        % are discarded.
        [p2Amps,c,phase,nullIndices] = reduceCoefficientsOverheadEnhancedType2(beta,numBeams,Mv,p2Amps,c,phase);
        % Quantize differential amplitudes p^(2)_{l,i,f}
        [p2,k2] = quantizeAmplitudesP2Rel16(p2Amps,1); % 2*numBeams-by-Mv-by-nLayers
        k2(nullIndices) = NaN;                         % 2*numBeams-by-Mv-by-nLayers
        bitmap(nullIndices) = 0;
    else
        % Quantize differential amplitudes p^(2)_{l,i,f}
        [p2,k2] = quantizeAmplitudesP2Rel16(p2Amps,1); % 2*numBeams-by-Mv-by-nLayers
    end

    stdAmps = 2.^((-8:0)/2);
    % Update the differential amplitudes (p^(2)_{l,i,f}) to limit the average
    % coefficient amplitude, as per TS 38.214 Section 5.2.2.2.6.
    for layerIdx = 1:nLayers
        for polIdx = 1:2
            for beamIdx = 1:numBeams
                beamNo = beamIdx + (polIdx-1)*numBeams;
                maxAvgCoeff = maximumAvgAmplitudes(beamNo);
                k3Temp = bitmap(beamNo,:,layerIdx);
                if any(k3Temp)
                    % Loop over all possible maximum amplitudes for the
                    % quantization of differential amplitudes. Begin with
                    % the highest possible amplitude and verify the average
                    % amplitude coefficient whether it is meeting the
                    % requirement based on codebook subset restriction or
                    % not. If yes, stop the process. If not, reduce the
                    % maximum possible amplitude for the quantization of
                    % differential amplitudes. Continue the process until
                    % the average coefficient amplitude requirement is met.
                    for stdAmpIdx = 9:-1:1
                        [p2(beamNo,:,layerIdx),k2(beamNo,:,layerIdx)] = quantizeAmplitudesP2Rel16(p2Amps(beamNo,:,layerIdx),stdAmps(stdAmpIdx));
                        avgAmpCoeff = sqrt((1/sum(k3Temp))*sum(k3Temp.*((p1(polIdx,1,layerIdx)*p2(beamNo,:,layerIdx)).^2)));
                        if avgAmpCoeff <= maxAvgCoeff
                            break;
                        end
                    end
                end
            end
        end
    end

    % Construct quantized BCC matrix W2q
    p20 = p2(1:numBeams,:,:);
    p21 = p2(numBeams+(1:numBeams),:,:);
    W2_quantized = [p10.*p20; p11.*p21].*exp(1i*phase);
end

function vlm = getVlm(N1,N2,O1,O2,l,m)
%   vlm = getVlm(N1,N2,O1,O2,l,m) computes vlm vector according to
%   TS 38.214 Section 5.2.2.2.1 considering the panel configuration
%   [N1, N2], DFT oversampling factors [O1, O2], and vlm indices l and m.

    um = exp(2*pi*1i*m*(0:N2-1)/(O2*N2));
    ul = exp(2*pi*1i*l*(0:N1-1)/(O1*N1)).';
    vlm =  reshape((ul.*um).',[],1);
end

function vbarlm = getVbarlm(N1,N2,O1,O2,l,m)
%   vbarlm = getVbarlm(N1,N2,O1,O2,l,m) computes vbarlm vector according to
%   TS 38.214 Section 5.2.2.2.1 considering the panel configuration
%   [N1, N2], DFT oversampling factors [O1, O2], and vbarlm indices l and m.

    % Calculate vbarlm (DFT vector required to compute the precoding matrix)
    um = exp(2*pi*1i*m*(0:N2-1)/(O2*N2));
    ul = exp(2*pi*1i*l*(0:(N1/2)-1)/(O1*N1/2)).';
    vbarlm = reshape((ul.*um).',[],1);
end

function [vlmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,n,i2Restriction)
%   [VLMRESTRICTED,I2RESTRICTED] = isRestricted(CODEBOOKSUBSETRESTRICTION,BITINDEX,N,I2RESTRICTION)
%   returns the status of vlm or vbarlm restriction and i2 restriction for
%   a codebook index set, as defined in TS 38.214 Section 5.2.2.2.1 by
%   considering these inputs:
%
%   CODEBOOKSUBSETRESTRICTION - Binary vector for vlm or vbarlm restriction
%   BITINDEX                  - Bit index or indices (0-based) associated
%                               with all the precoding matrices based on
%                               vlm or vbarlm
%   N                         - Co-phasing factor index
%   I2RESTRICTION             - Binary vector for i2 restriction

    % Get the restricted index positions from the codebookSubsetRestriction
    % binary vector
    restrictedIdx = reshape(find(~codebookSubsetRestriction)-1,1,[]);
    vlmRestricted = false;
    if any(sum(restrictedIdx == bitIndex(:),2))
        vlmRestricted = true;
    end

    restrictedi2List = find(~i2Restriction)-1;
    i2Restricted = false;
    % Update the i2Restricted flag, if the precoding matrices based on vlm
    % or vbarlm are restricted
    if any(restrictedi2List == n)
        i2Restricted = true;
    end
end

function [i14P] = quantizeAmplitudesP1Rel15(amplitudeVals,maxAllowableAmp)
% i14P = quantizeAmplitudesP1Rel15(AMPLITUDEVALS,MAXALLOWABLEAMP) returns
% the amplitude index i14P value for the given amplitude value
% AMPLITUDEVALS, rounded off to the standard defined wideband amplitudes
% for type II codebooks considering the maximum allowable amplitude
% MAXALLOWBLEAMP, defined from codebook subset restriction

    stdAmps = round([0 sqrt(1/64) sqrt(1/32) sqrt(1/16) sqrt(1/8) sqrt(1/4) sqrt(1/2) 1],4,'decimals');
    allowedAmps = stdAmps(1:find(stdAmps == maxAllowableAmp));
    if isscalar(allowedAmps) % Possible amplitude is zero only
        i14P = 0;
    else
        logStdAmps = log(allowedAmps);
        logStdAmps(1) = 2*logStdAmps(2) - logStdAmps(3);
        [~,idx] = min(abs(log(amplitudeVals) - logStdAmps));
        i14P = allowedAmps(idx);
    end
end

function i14K = mapPToKVals(amplitudes)
% i14K = mapPToKvals(AMPLITUDES) returns the amplitude indices i14K for the
% given standard defined amplitude values AMPLITUDES mapped to the wideband
% amplitudes as defined in TS 38.214 Table 5.2.2.2.3-2 for type II
% codebooks

    stdAmps = round([0 sqrt(1/64) sqrt(1/32) sqrt(1/16) sqrt(1/8) sqrt(1/4) sqrt(1/2) 1],4,'decimals');
    i14K = ones(size(amplitudes));
    for ii = 1:numel(amplitudes)
        idx = find(stdAmps == amplitudes(ii));
        i14K(ii) = idx;
    end

end

function maxAllowableAmpWithIndex = codebookSubsetRestrictionXType2(bitVector,panelDimensions)
% MAXALLOWABLEAMPWITHINDEX = codebookSubsetRestrictionXType2(BITVECTOR,PANELDIMENSIONS)
% returns the maximum allowable amplitude for the indices denoted by the
% codebook subset restriction BITVECTOR. The indices and the corresponding
% maximum amplitudes are extracted from the bit vector BITVECTOR for the
% given panel dimensions PANELDIMENSIONS. This is applicable only to
% Type II and enhanced type II codebooks. For enhanced type II codebooks,
% maximum allowable amplitude represents the maximum average coefficient
% amplitude

    N1 = panelDimensions(1);
    N2 = panelDimensions(2);
    O1 = 4;
    O2 = 1 + 3*(N2>1); % 1 for N2 = 1 and 4 for N2 > 1
    r1 = 0:O1-1;
    r2 = repmat(0:O2-1,1,4/O2);
    n1n2Prod = N1*N2;
    o1o2Prod = O1*O2;
    % Obtain the r1 r2 indices from B1 part of bit vector B
    if N2 > 1
        B = bitVector(1:11); % b0,b1,b2,...b10, right-side MSB
        beta1 = bit2int(B(:),11,false); % Convert the bit vector to an integer by considering the right-side MSB
        s = 0;
        g = zeros(1,4);
        for k = 0:3
            y = NaN(o1o2Prod,1);
            for xRange = 3-k:o1o2Prod-1-k
                y(xRange+1) = 0;
                if 4-k <= xRange
                    y(xRange+1) = nchoosek(xRange,4-k);
                end
            end
            e = max(y(y<=(beta1-s)));
            x = find(y==e)-1;
            s = s+e;
            g(k+1) = o1o2Prod-1-x;
            r1(k+1) = mod(g(k+1),O1);
            r2(k+1) = (g(k+1) - r1(k+1))/O1;
        end
    end

    % Extract the bit vector B2, which is in the form of [B2(0) B2(1) B2(2) B2(3)]
    if O2>1
        B2 = bitVector(12:end);
    else
        B2 = bitVector; % Entire bit vector represents B2, as B1 is empty
    end

    % Obtain the maximum allowable amplitudes corresponding to the DFT
    % vectors of beam groups denoted by the bit vector B1
    maxAllowableAmpWithIndex = [];
    for k = 0:3
        B2ksequence = B2(2*n1n2Prod*k+1:2*n1n2Prod*(k+1)); % bit vector of length 2N1N2. It is in the form of b2k(0),b2k(1),...,b2k(2N1N2-1)
        for x1= 0:N1-1
            for x2 = 0:N2-1
                extractedbits = [B2ksequence(2*(N1*x2+x1)+1+1); B2ksequence(2*(N1*x2+x1)+1)] ;
                p = round([0 1/sqrt(4) 1/sqrt(2) 1],4,'decimals');
                maxAllowableAmpWithIndex = [maxAllowableAmpWithIndex; N1.*r1(k+1)+x1 N2.*r2(k+1)+x2 p(bit2int(extractedbits,2)+1)]; %#ok<AGROW> 

            end
        end
    end
end

function EigVectors = getSubbandChannelEigenvectors(H_bwp,subbandInfo,csirsIndBWP_k,csirsIndBWP_l)
%   EIGVECTORS = getSubbandChannelEigenvectors(H_BWP,SUBBANDINFO,CSIRSINDBWP_K,CSIRSINDBWP_L)
%   returns the eigenvectors for all the subbands EIGVECTORS, given the
%   channel estimation matrix H_BWP, subband related information
%   SUBBANDINFO, and CSI-RS indices CSIRSINDSUBS_K

    % Compute the channel covariance matrix and its eigenvectors
    Hcov = pagemtimes(H_bwp,'ctranspose',H_bwp,'none');
    [~,~,Hv] = pagesvd(Hcov);

    % Compute the channel eigenvectors
    numSubbands = subbandInfo.NumSubbands;
    EigVectors = zeros([size(Hcov,1:2),numSubbands]);
    subbandStart = 0;
    Hv_temp = reshape(Hv,size(Hv,1),size(Hv,2),[]);
    for sbIdx = 1:numSubbands
        sc(1) = subbandStart*12 + 1;
        sc(2) = (subbandStart + subbandInfo.SubbandSizes(sbIdx))*12;
        % Subcarriers spanning the given subband
        k = ( sc(1) <= csirsIndBWP_k) & ( csirsIndBWP_k <= sc(2));        
        Hv_SB = Hv_temp(:,:,csirsIndBWP_k(k)+(csirsIndBWP_l(k)-1)*size(H_bwp,3));

        % Extract the eigenvectors associated with this subband and
        % compute the average eigenvector
        if ~isempty(Hv_SB)
            EigVectors(:,:,sbIdx) = mean(Hv_SB,3);
        end

        % First RB of next subband
        subbandStart = subbandStart + subbandInfo.SubbandSizes(sbIdx);
    end
end

function [numBeams,pv,beta] = getEnhancedType2ParameterCombinations(combIdx,nLayers)
%   [NUMBEAMS,PV,BETA] = getEnhancedType2ParameterCombinations(COMBIDX,NLAYERS)
%   returns the parameters related to enhanced type 2 codebook, given the
%   combination index COMBIDX and number of transmission layers NLAYERS, as
%   defined in TS 38.214 Table 5.2.2.2.5-1.

    table = [   1   2   1/4     1/8     1/4;
                2   2   1/4     1/8     1/2;
                3   4   1/4     1/8     1/4;
                4   4   1/4     1/8     1/2;
                5   4   1/4     1/4     3/4;
                6   4   1/2     1/4     1/2;
                7   6   1/4     NaN     1/2;
                8   6   1/4     NaN     3/4];
    rowIdx = table(:,1) == combIdx;
    row = table(rowIdx,:);
    numBeams = row(2);
    pv = row(3+floor((nLayers-1)/2));
    beta = row(5);

end

function [i1,i2] = eType2Indices_afterRemapping(N3,Mv,q1,q2,i12,k1,k2,c,istar,fstar,Minit,n3)
%   [i1,i2] = eType2Indices_afterRemapping(N3,Mv,q1,q2,i12,k1,k2,c,istar,fstar,Minit,n3)
%   forms the PMI indices

    nLayers = size(n3,2);
    numBeams = size(k2,1)/2;

    % Calculate i2l indices for each layer and concatenate to create i2
    i23 = reshape(k1,[2 nLayers]);

    % Calculate i17, the bitmap indicating the reported i24 and i25
    % indices. Don't report indices marked as NaN.
    k3 = true([2*numBeams Mv nLayers]);
    k3(isnan(k2)) = false;

    % Remapping of n3 needs to be done to make n3(strongestBeam) = 0. Since
    % the DFT bases Vm are sorted (strong to weak), the first row of n3
    % contains the n^(f*)_(3,l). For that reason, there is no need to remap
    % i24 (k(2)), i25 (c), i17 (k(3)).
    for lay = 1:nLayers
        k2(:,:,lay) = circshift(k2(:,:,lay),-(fstar(lay)-1),2);
        k3(:,:,lay) = circshift(k3(:,:,lay),-(fstar(lay)-1),2);
        c(:,:,lay) = circshift(c(:,:,lay),-(fstar(lay)-1),2);
    end
    i24 = reshape(k2,[2*numBeams*Mv nLayers]);
    i25 = reshape(c,[2*numBeams*Mv nLayers]);
    i2 = reshape([i23; i24; i25],1,[]);

    % Calculate i15 and i16 indices
    if N3 <= 19
        i15 = 0;
    else
        i15 = Minit + 2*Mv*(Minit<0);
    end

    i16 = geti16EnhancedType2(N3,Mv,n3,i15);

    % Calculate i17 and i18 indices
    i17 = reshape(k3,[2*numBeams*Mv nLayers]);     

    % Calculate the index of the strongest coefficient of
    % layer l, i18l.
    if nLayers == 1
        i18 = reshape(sum(k3(1:istar,1))-1,1,[]);
    else
        i18 = reshape(istar,1,[]);
    end

    % Collect all i1 indices except i11 (q1,q2) and i12
    i1WB = [q1 q2 i12 i15];
    i1SB = [i16; i17; i18];
    i1 = [i1WB i1SB(:).'];

end

function i16 = geti16EnhancedType2(N3,Mv,n3lf,i15)
%   i16 = geti16EnhancedType2(N3,Mv,n3lf,i15) calculates codebook index i16
%   corresponding to n3lf and i15 for a number of subbands N3 and number of
%   DFT bases for FDD compression Mv. When N3 <= 19, i16 indexes the set of
%   combinations of Mv elements picked from N3 DFT bases. When N3>19, i16
%   indexes the set of combinations of Mv elements picked from 2*Mv. The
%   set of contiguous 2*Mv DFT bases is a window with offset determined by
%   i15.

    n3lf = sort(n3lf);
    if N3 <= 19
        nLayers = size(n3lf,2);
        i16 = zeros(1,nLayers);
        for p = 1:nLayers
            c = 0;
            for f=1:Mv-1
                n = N3-1-(n3lf(1+f,p));
                k = Mv-f;
                if (n>0) && (n>=k)
                    c = c + nchoosek(n,k);
                end
            end
            i16(p) = c;
        end
    else % N3 > 19
        Minit = i15 - 2*Mv*(i15>0);
        c1 = ( n3lf <= (Minit + 2*Mv - 1) );
        c2 = ( n3lf >  (Minit + N3 - 1) );
        n = zeros(size(n3lf));
        n(c1) = n3lf(c1);
        n(c2) = n3lf(c2) - (N3-2*Mv);
        i16 = geti16EnhancedType2(2*Mv,Mv,n,0);
    end
end

function W1 = getW1(N1,N2,O1,O2,m1,m2)
%   W1 = getW1(N1,N2,O1,O2,m1,m2) returns the wideband beam group matrix W1
%   for all beams associated to the vectors m1 and m2, given the panel
%   dimensions N1, N2, and oversampling factors O1, O2.

    numBeams = length(m1);
    vm1m2 = zeros(N1*N2,numBeams);
    for beam = 1:numBeams
        vlm = getVlm(N1,N2,O1,O2,m1(beam),m2(beam));
        vm1m2(:,beam) = vlm;
    end
    vmats = reshape(vm1m2,N1*N2,[]);
    W1 = blkdiag(vmats,vmats);
end

function [p1,k1] = quantizeAmplitudesP1Rel16(Ain,maxAllowableAmp)
%   [P1,K1] = quantizeAmplitudesP1Rel16(AIN,MAXALLOWABLEAMP) returns the
%   quantized amplitudes P1 and their indices K1 for the given amplitude
%   values AIN by considering the maximum allowable amplitude
%   MAXALLOWABLEAMP, as defined in TS 38.214 Table 5.2.2.2.5-2

    sizeIn = size(Ain);
    A = reshape(Ain,[1 1 prod(sizeIn)]);
    stdAmps = 2.^((-15:0)/4); 
    allowedAmps = stdAmps(1:find(stdAmps == maxAllowableAmp));
    [~,idx] = min(abs(log(A) - log(allowedAmps)));
    idx = reshape(idx,sizeIn);

    k1 = idx; % 1-based indices

    p1 = zeros(size(k1));
    p1(:) = stdAmps(idx);

    nullCoeff = idx == 1;
    p1(nullCoeff) = 0; % Considering this as zero as it is defined as reserved in TS 38.214 Table 5.2.2.2.5-2

end

function [p2,k2] = quantizeAmplitudesP2Rel16(Ain,maxAllowableAmp)
%   [P2,K2] = quantizeAmplitudesP2Rel16(AIN,MAXALLOWABLEAMP) returns the
%   quantized amplitudes P2 and their indices K2 for the given amplitude
%   values AIN by considering the maximum allowable amplitude
%   MAXALLOWBLEAMP, as defined in TS 38.214 Table 5.2.2.2.5-3

    sizeIn = size(Ain);
    A = reshape(Ain,[1 1 prod(sizeIn)]);
    stdAmps = 2.^((-8:0)/2);
    allowedAmps = stdAmps(1:find(stdAmps == maxAllowableAmp));
    [~,idx] = min(abs(log(A) - log(allowedAmps)),[],2);
    idx = reshape(idx,sizeIn);

    k2 = idx-1; % 1-based indices

    p2 = zeros(size(k2));
    p2(:) = stdAmps(idx);

    nullCoeff = k2 == 0;
    k2(nullCoeff) = NaN;
    p2(nullCoeff) = 0;

end

function [m1,m2] = getm1m2Index(N1,N2,O1,O2,numBeams)
%   [M1,M2] = getm1m2Index(N1,N2,O1,O2,NUMBEAMS) returns M1 and M2 indices
%   for all the beam combinations, given the panel dimensions N1 and N2,
%   oversampling factors O1 and O2, and number of beams NUMBEAMS

    N1N2 = N1*N2;
    n = flipud(nchoosek(0:N1N2-1,numBeams));

    q1 = (0:O1-1);
    q2 = (0:O2-1);

    n1 = mod(n,N1);
    n2 = floor((n - n1)/N1);

    q1 = shiftdim(q1,-1);
    q2 = shiftdim(q2,-1);

    m1 = O1*n1 + q1;
    m2 = O2*n2 + q2;

end

function [amps,c,phase,nullIndices] = reduceCoefficientsOverheadEnhancedType2(beta,numBeams,Mv,amps,c,phase)
%   [AMPS,C,PHASE,NULLINDICES] = reduceCoefficientsOverheadEnhancedType2(BETA,NUMBEAMS,MV,AMPS,C,PHASE)
%   limits the number of amplitude and phase coefficients per layer to K0
%   by maintaining a total of 2K0 number of non-zeros elements across all
%   the layers

    % Sort amplitudes and null the weakest 2*numBeams*Mv*nLayers-2*K0 elements in
    % p2, k2, c, and phase.
    K0 = ceil(beta*2*numBeams*Mv);
    nLayers = size(amps,3);
    totCoeff = 2*numBeams*Mv*nLayers;
    p2_reshaped = amps(:); % Of size 2*numBeams*Mv*nLayers-by-1
    [~,idx] = sort(p2_reshaped);
    nullIndices = idx(1:totCoeff-(2*K0));

    % Find the indices in subscript form
    [aa,bb] = ind2sub([2*numBeams*Mv nLayers],idx);
    aaStrong = aa(totCoeff-((1+nLayers>1)*K0)+1:end);
    bbStrong = bb(totCoeff-((1+nLayers>1)*K0)+1:end); % Layer indices

    % Find if any layer is having more than K0 non-zero values
    noOfNZValsForEachLayer = sum(bbStrong == 1:nLayers);
    layerIndexExceedingK0 = find(noOfNZValsForEachLayer > K0);

    if ~isempty(layerIndexExceedingK0)
        % Store the indices set which don't need any action
        aaArray = [aaStrong(bbStrong ~= layerIndexExceedingK0); aaStrong(find(bbStrong == layerIndexExceedingK0,K0,'last'))];
        bbArray = [bbStrong(bbStrong ~= layerIndexExceedingK0); bbStrong(find(bbStrong == layerIndexExceedingK0,K0,'last'))];
        % Extract the weaker coefficient indices set
        aaWeaker = aa(1:totCoeff-(2*K0));
        bbWeaker = bb(1:totCoeff-(2*K0));
        % Find the number of values which needs to be adjusted in another layer(s)
        noOfValsToAdjustInOtherLayer = noOfNZValsForEachLayer(layerIndexExceedingK0) - K0;
        % Get the layer indices set in which we can adjust the NZ coefficients
        layIndOfInterest = bbWeaker ~= layerIndexExceedingK0;
        indicesOfNextStrCoeff = find(layIndOfInterest,noOfValsToAdjustInOtherLayer,'last');

        % Update the indices set by adjusting the coefficients across
        % layers
        aaArray = [aaArray; aaWeaker(indicesOfNextStrCoeff)];
        bbArray = [bbArray; bbWeaker(indicesOfNextStrCoeff)];

        % Get the indices set in linear form
        strIndicesLinear = aaArray + (bbArray-1)*(2*numBeams*Mv);
        tmpIndices = zeros(2*numBeams*Mv*nLayers,1);
        tmpIndices(strIndicesLinear) = 1;
        nullIndices = find(tmpIndices == 0);
    end

    % Amplitudes
    amps(nullIndices) = 0;

    % Phases
    c(nullIndices) = NaN;
    phase(nullIndices) = 0;
end

function SINRPerRE = computeSINRPerRE(Hcsirs,codebook,nVar,csirsIndBWP_k,indexSetSizes)
%   SINRPerRE = computeSINRPerRE(Hcsirs,codebook,nVar,csirsIndBWP_k,indexSetSizes)
%   computes SINR per RE level for all the precoding matrices

    csirsIndSubs_length = numel(csirsIndBWP_k);
    nLayers = size(codebook,2);
    SINRPerRE = zeros([csirsIndSubs_length,nLayers,indexSetSizes]);
    if(csirsIndSubs_length < prod(indexSetSizes)) % Consider precoding matrix as page matrix
        for reIdx = 1:csirsIndSubs_length
            % Calculate the linear SINR values for each CSI-RS RE
            % by considering all unrestricted precoding matrices
            Htemp = Hcsirs(:,:,reIdx);
            sinr = nr5g.internal.nrPrecodedSINR(Htemp,nVar,codebook);
            SINRPerRE(reIdx,:) = sinr(:);
        end
    else % Consider channel matrix as page matrix
        for Indx = 1:prod(indexSetSizes)
            if any(codebook(:,:,Indx),'all')
                % Calculate the linear SINR values of all the CSI-RS
                % REs for each precoding matrix
                SINRPerRE(:,:,Indx) = nr5g.internal.nrPrecodedSINR(Hcsirs,nVar,codebook(:,:,Indx));
            end
        end
    end
end
