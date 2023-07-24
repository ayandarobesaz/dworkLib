
function [ img, sMaps ] = mri_reconJSENSE( kData, varargin )
  % [ img, sMaps ] = mri_reconJSENSE( kData [, 'maxIter', maxIter, 'polyOrder', polyOrder,
  %   'relDiffThresh', relDiffThresh ] );
  %
  % Inputs:
  % kData - a two dimensional array of complex values; uncollected data have values of 0
  %         Its size is [ nKy nKx nCoils ].
  %
  % Optional Inputs:
  % maxIter - a scalar reprenting the maximum number of iterations
  % polyOrder - either a scalar representing the order in both dimensions or
  %             a two element array representing [ yOrder xOrder ]
  % relDiffThresh - dynamic stopping criteria for joint estimation iterations
  %
  % Outputs:
  % img - a two dimensional complex array that is the reconstructed image
  %
  % Optional Outputs:
  % sMaps - a three dimensional complex array of the sensitivity maps
  %
  % Written by Nicholas Dwork - Copyright 2023
  %
  % https://github.com/ndwork/dworkLib.git
  %
  % This software is offered under the GNU General Public License 3.0.  It
  % is offered without any warranty expressed or implied, including the
  % implied warranties of merchantability or fitness for a particular
  % purpose.

  if nargin < 1
    disp([ 'Usage: [ img, sMaps ] = mri_reconJSENSE( kData [, ''maxIter'', maxIter, ', ...
      '''polyOrder'', polyOrder ] ); ' ]);
    if nargout > 0, img=[]; end
    if nargout > 1, sMaps=[]; end
    return
  end

  p = inputParser;
  p.addParameter( 'maxIter', 10, @(x) ispositive(x) && mod(x,1)==0 );
  p.addParameter( 'polyOrder', [], @(x) isnonnegative(x) && isinteger(x) );
  p.addParameter( 'relDiffThresh', 0 );
  p.parse( varargin{:} );
  maxIter = p.Results.maxIter;
  polyOrder = p.Results.polyOrder;
  relDiffThresh = p.Results.relDiffThresh;

  img = mri_reconSSQ( kData );

  for iter = 1 : maxIter
    disp([ 'Working on JSENSE iteration ', num2str(iter) ]);

    sMaps = mri_makeSensitivityMaps( kData, img, 'polyOrder', polyOrder, 'alg', 'ying' );

    img = mri_reconModelBased( kData, sMaps );

    if relDiffThresh > 0
      objDiff = ( objValue - lastObjValue ) / lastObjValue;
      if objDiff < relDiffThresh
        break;
      end
    end
  end
end

