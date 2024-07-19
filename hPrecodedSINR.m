function sinr = hPrecodedSINR(H,nVar,W)
%hPrecodedSINR(H,nVar,W) MMSE SINR calculation
%   SINR = hPrecodedSINR(H,NVAR,W) returns the linear minimum mean square
%   error (MMSE) signal to interference plus noise ratio (SINR) values
%   corresponding to the channel matrix H, noise variance NVAR, and
%   precoding matrices W. The channel matrix H is of size R-by-P-by-NRE,
%   where R is the number of receive antennas, P is the number of transmit
%   antennas, and NRE is the number of resource elements.
%
%   The MMSE SINR metric is gamma = 1/(NVAR*(W'H'HW+NVAR*I)^(-1)) - 1, with
%   I identity matrix. 
% 
%   See also nrChannelEstimate, nrPUSCHCodebook.

%   Copyright 2022 The MathWorks, Inc.

%   Notes: The implementation in this function relies on the following.
%   For each RE, R = H * W, where R = U * S * V', U and V unitary, S diagonal
%   matrix (SVD decomposition). U is RxP, S is diagonal PxP and V is PxP.
%
%   R' * R + nVar * I = V * S' * U' * U * S * V' + nVar * I ....
%   = V * (S^2 + nVar * I) * V'
%   if den = inv(R' * R + nVar * I) 
%   den = V * inv(S^2 + nVar * I) * V' 
%   den = V * (1 ./ (Sd^(2) + nVar) .* I) * V' 
%
%   where Sd is diag(S). Adding nVar has no impact on U or V, just adds
%   nVar to the singular values of R. The use of SVD avoids the need for a
%   matrix inverse, instead
% 
%   a1 = 1 ./ (Sd^(2) + nVar).
%   a2 = 1 ./ diag(nVar*(V .* a1') * V') = 1 ./ (nVar * diag((V .* a1') * V')),
%   which is simplified to 
%   a2 = 1 ./ (nVar * sum( a1' .* (V .* conj(V)), 2)) and the SINR values
%   are obtained by calculating real(a2-1).
%
%   In code below, second letter "b" on u, s, and v is short for "big",
%   since we are treating with all REs in one go.

	% Calculate the SINR values as per LMMSE method
    R = pagemtimes(H,W);
    [~, sb, vb] = pagesvd(R,"econ","vector"); % sb in columns

    % If H is a 2D matrix, compute SINR values using W as the page matrix,
    % otherwise, consider using the channel matrix as the page matrix
    if(size(H,3)==1)
        a1 = (1./(sb.^2+nVar)); % 1./(Sd^(2)+nVar)
        a2 = 1./(nVar*squeeze(sum(pagetranspose(a1) .* (abs(vb) .^2), 2))); % Same as 1./diag( nVar*(V.*a1')*V' )
    else
        a1=1./(pagetranspose(sb .* sb)+(nVar*ones(1,size(W,2)))); % 1./(Sd^(2)+nVar)
        a2 = (nVar*permute(sum(a1 .* (abs(vb) .^2), 2),[3 1 2])).^-1; % Same as 1./diag( nVar*(V.*a1')*V' );
    end
    sinr = real(a2-1);
end