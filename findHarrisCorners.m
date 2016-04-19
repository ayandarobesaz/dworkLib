

function corners = findHarrisCorners( img, varargin )
  % corners = findHarrisCorners( img [, N, buffer, w, k ] )
  %
  % Inputs:
  % img - a 2D array
  % N - the number of features to identify (default is 50)
  % buffer - the minimum spacing between features (default is 20)
  % w - the width of the kernel (default is 7)
  % k - Harris corner detector parameter
  %
  % Outputs:
  % corners - an Nx2 array.  The first/second column is the y/x coordinate
  %   of each feature.
  %
  % Written by Nicholas Dwork 2016

  defaultN = 50;
  defaultW = 7;
  defaultBuffer = 20;
  defaultK = 0.04;
  p = inputParser;
  p.addOptional( 'N', defaultN );
  p.addOptional( 'buffer', defaultBuffer );
  p.addOptional( 'w', defaultW );
  p.addOptional( 'k', defaultK );
  p.parse( varargin{:} );
  N = p.Results.N;
  buffer = p.Results.buffer;
  w = p.Results.w;
  k = p.Results.k;

  sImg = size( img );

  Ix = zeros( sImg );
  Ix(:,1:end-1) = img(:,2:end) - img(:,1:end-1);

  Iy = zeros( sImg );
  Iy(1:end-1,:) = img(2:end,:) - img(1:end-1,:);

  IxSq = Ix .* Ix;
  IySq = Iy .* Iy;
  IxIy = Ix .* Iy;

  G11 = smooth( IxSq, w );
  G22 = smooth( IySq, w );
  G12 = smooth( IxIy, w );

  trG = G11 .* G22;
  detG = trG - G12 .* G12;
  score = detG - k * trG .* trG;

  minScore = min( score(:) );
  score(1:buffer,:) = minScore;
  score(:,1:buffer) = minScore;
  score(end-buffer:end,:) = minScore;
  score(:,end-buffer:end) = minScore;

  corners = zeros(N,2);
  for i=1:N
    [~,maxIndx] = max( score(:) );
    [y,x] = ind2sub( sImg, maxIndx );
    corners(i,1) = y;
    corners(i,2) = x;

    bIndx = max( y-buffer, 1 );
    uIndx = min( y+buffer, sImg(1) );
    LIndx = max( x-buffer, 1 );
    rIndx = min( x+buffer, sImg(2) );
    score(bIndx:uIndx,LIndx:rIndx) = minScore;
    
    if max(score(:)) == minScore, break; end;
  end
end




