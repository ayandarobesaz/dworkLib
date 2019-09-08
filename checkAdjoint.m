
function [out,err] = checkAdjoint( x, f_in, varargin )
  % out = checkAdjoint( x, f [, fAdj, 'tol', tol, 'y', y, 'nRand', nRand ] )
  %
  % Check whether the adjoint of f is implemented correctly
  %
  % Inputs:
  % x - a sample input (specifies size) of the function; it will be tested first.
  % f - a function handle specifying the function of interest
  %
  % Optional Inputs:
  % fAdj - if supplied, this function is the adjoint.  If it isn't supplied, it is assumed
  %   that f accepts two arguments: the input, and 'transp' or 'notransp' specifying whether
  %   or not to return the adjoint
  % tol - error must be larger than this value for check to fail
  % y - if supplied, then checks this (x,y) pair first.  Othersize, just checks zeros
  %     and random values
  % nRand - number of random inputs to check
  %
  % Outputs:
  % out - returns true if check passed; otherwise, returns false
  % err - returns the maximum relative error of all tests conducted
  %
  % Written by Nicholas Dwork
  %
  % This software is offered under the GNU General Public License 3.0.  It
  % is offered without any warranty expressed or implied, including the
  % implied warranties of merchantability or fitness for a particular
  % purpose.

  p = inputParser;
  p.addOptional( 'fAdj', [] );
  p.addParameter( 'nRand', 1, @isnumeric );
  p.addParameter( 'tol', 1d-6, @isnumeric );
  p.addParameter( 'y', [], @isnumeric );
  p.parse( varargin{:} );
  fAdj = p.Results.fAdj;
  nRand = p.Results.nRand;
  tol = p.Results.tol;
  y = p.Results.y;

  if numel( fAdj ) == 0
    f = @(x) f_in( x, 'notransp' );
    fAdj = @(x) f_in( x, 'transp' );
  else
    f = f_in;
  end

  out = true;

  if min( isreal(x) ) == 0
    dataIsComplex = true;
  else
    dataIsComplex = false;
  end
  
  err = 0;
  fx = f(x);
  if numel(y) == 0
    y = rand( size(fx) );
    if dataIsComplex
      y = y + 1i * rand( size(fx) );
    end
  else
    fTy1s = fAdj( y );
    err = abs( dotP( fx, y ) - dotP( x, fTy1s ) );
    if err > tol
      out = false;
      return;
    end
  end

  % Try all ones
  x1s = ones( size( x ) );
  fx1s = f( x1s );
  y1s = ones( size( y ) );
  fTy1s = fAdj( y1s );
  dp1 = dotP( fx1s, y1s );
  dp2 = dotP( x1s, fTy1s );
  if dp1 > tol * 0.1
    tmpErr = abs( dp1 - dp2 ) / abs( dp1 );
  else
    tmpErr = abs( dp1 - dp2 );
  end
  err = max( err, tmpErr );
  if err > tol
    out = false;
    return;
  end

  % Try random vectors
  for rIndx = 1 : nRand
    rx = rand( size( x ) );
    if dataIsComplex, rx = rx + 1i * rand( size( x ) ); end
    frx = f( rx );
    ry = rand( size ( y ) );
    if dataIsComplex, ry = ry + 1i * rand( size( x ) ); end
    fTry = fAdj( ry );
    dp1 = dotP ( frx, ry );
    dp2 = dotP( rx, fTry );
    if dp1 > tol * 0.1
      tmpErr = abs( dp1 - dp2 ) / abs( dp1 );
    else
      tmpErr = abs( dp1 - dp2 );
    end
    err = max( err, tmpErr );
    if err > tol
      out = false;
      return;
    end
  end

end


