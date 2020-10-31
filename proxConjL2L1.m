
function out = proxConjL2L1( x, sigma, t )
  % out = proxConjL2L1( x, sigma, t )
  %
  % Calculates the proximal operator of sigma times the conjugate
  % of f(x) = t * L2L1( x )
  %
  % Inputs:
  % x - an N Dimensional array where the last dimension represents the groups
  % sigma - scaling of proximal operator
  % t - a scalar
  %
  % Written by Nicholas Dwork - Copyright 2020
  %
  % This software is offered under the GNU General Public License 3.0.  It
  % is offered without any warranty expressed or implied, including the
  % implied warranties of merchantability or fitness for a particular purpose.

  if sigma == 0
    out = x;
    return;
  end

  if nargin < 3, t = 1; end

  nx = norms( x );
  scalings = ones( size( nx ) );
  scalings( nx > t ) = t ./ nx( nx > t );

  out = bsxfun( @times, x, scalings );
end
