function Lmodel = update_ewma(list,path,Lmodel,lambda,step,debug)

% Big data analysis based on bilinear proyection models (PCA and PLS), EWMA
% approach.
%
% Lmodel = update_ewma(list)          % minimum call
% Lmodel = update_ewma(list,path,Lmodel,lambda,step,debug) % complete call
%
% INPUTS:
%
% list: {Fx1} list of strings with the names of the files for the update or
%   struct array with x (and optionally y) matrices.
%
% path: (str) path to the directory where the data files are located ('' by
%   default)
%
% Lmodel: (struct Lmodel) model to update (initialized to PCA model with 1
%   PC and auto-scaling by default)
%
% lambda: (1x1) forgetting factor between 0 (fast adaptation) and 1 (long
%   history) (1 by default)
%
% step: (1x1) percentage of the data in the file to be used in each
%   iteration. For time-course data 1 is suggested (1 by default)
%
% debug: (1x1) disply debug messages
%       0: no messages are displayed.
%       1: display only main messages (default)
%       2: display all messages.  
%
%
% OUTPUTS:
%
% Lmodel: (struct Lmodel) model updated.
%
%
% coded by: Jose Camacho Paez (josecamacho@ugr.es)
% last modification: 06/Feb/15
%
% Copyright (C) 2014  University of Granada, Granada
% Copyright (C) 2014  Jose Camacho Paez
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
%% Parameters checking

if nargin < 1, error('Error in the number of arguments.'); end;
if nargin < 2, path = ''; end;
if nargin < 3, 
    Lmodel = Lmodel_ini; 
    Lmodel.type = 1;
    Lmodel.lv = 1;
    Lmodel.prep = 2;
end;
if nargin < 4, lambda = 1; end;
if nargin < 5, step = 1; end;
if nargin < 6, debug = 1; end;
    
    
% Computation

Lmodel.update = 1; 
    
for t=1:length(list),
    
    if debug, disp(sprintf('clustering: packet %d...........................................', t)), end;
    
    if Lmodel.type==1,
        if isstruct(list(t))
            x = list(t).x;
        else
            load([path list{t}],'x')
        end
    elseif Lmodel.type==2,
        if isstruct(list(t))
            x = list(t).x;
            y = list(t).y;
        else
            load([path list{t}],'x','y')
        end
    end
    
    if isstruct(list(t))
        vars = fieldnames(list(t));
        if ismember('class', vars)
            class = list(t).class;
        else
            class = ones(size(x,1),1);
        end
        if ismember('obs_l', vars)
            obs_l = list(t).obs_l;
        else
            obs_l = {};
        end
    else
        vars = whos('-file',[path list{t}]);
        if ismember('class', {vars.name})
            load([path list{t}],'class')
        else
            class = ones(size(x,1),1);
        end
        if ismember('obs_l', {vars.name})
            load([path list{t}],'obs_l')
        else
            obs_l = {};
        end
    end
    
    N = Lmodel.N;
    [xcs,Lmodel.av,Lmodel.sc,Lmodel.N] = preprocess2Di(x,Lmodel.prep,0,lambda,Lmodel.av,Lmodel.sc,Lmodel.N);
    
    Lmodel.XX = lambda*Lmodel.XX + xcs'*xcs;
    
    if Lmodel.type==1
        
        [P,sdT] = Lpca(Lmodel);
        Lmodel.mat = P*diag(1./sdT);
        
    elseif Lmodel.type==2,
        
        [ycs,Lmodel.avy,Lmodel.scy] = preprocess2Di(y,Lmodel.prepy,0,lambda,Lmodel.avy,Lmodel.scy,N);
        
        Lmodel.XY = lambda*Lmodel.XY + xcs'*ycs;
        Lmodel.YY = lambda*Lmodel.YY + ycs'*ycs;
        
        if rank(Lmodel.XY)>0,
            
            [beta,W,P,Q,R,sdT] = Lpls(Lmodel);
            Lmodel.mat = R*diag(1./sdT);
            
        else
            
            if debug>1, disp('XY Rank 0: using PCA.'), end;
            
            [P,sdT] = Lpca(Lmodel);
            Lmodel.mat = P*diag(1./sdT);
            
        end
        
    end
    
    Lmodel.multr = lambda*Lmodel.multr;
    ind_lab = find(Lmodel.multr>1);
    Lmodel.centr =  Lmodel.centr(ind_lab,:);
    Lmodel.multr = Lmodel.multr(ind_lab);
    Lmodel.class = Lmodel.class(ind_lab);
    if ~isempty(Lmodel.obs_l)
        Lmodel.obs_l = Lmodel.obs_l(ind_lab);    
    end

    s = size(x);
    step2 = max(10,round(s(1)*step));
    for i = 1:step2:s(1),
        endv = min(s(1),i+step2);
        ss = endv-i+1;
        xstep = xcs(i:endv,:);
        clstep = class(i:endv,:);
        if isempty(obs_l)
            obs_step = {};
        else
            obs_step = obs_l(i:endv);
        end
               
        Lmodel.centr = [Lmodel.centr;xstep];
        Lmodel.multr = [Lmodel.multr;ones(ss,1)];
        Lmodel.class = [Lmodel.class;clstep];
        Lmodel.obs_l = {Lmodel.obs_l{:} obs_step{:}};
            
        [Lmodel.centr,Lmodel.multr,Lmodel.class,Lmodel.obs_l] = psc(Lmodel.centr,Lmodel.nc,Lmodel.multr,Lmodel.class,Lmodel.obs_l,Lmodel.mat);

    end
    
end

if Lmodel.type==1, % Update mat acording to actual scores
    Lmodel.mat = P;
elseif Lmodel.type==2,
    if rank(Lmodel.XY)>0,
        Lmodel.mat = R;
    else
        Lmodel.mat = P;
    end
end
T = Lmodel.centr*Lmodel.mat;
mM = max(T)-min(T);
Lmodel.mat = Lmodel.mat*diag(1./mM);
