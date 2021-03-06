function FECGSYN_bss_compare(path)
% function FECGSYN_bss_compare
%
% This script used in Andreotti et al 2016, experiment 1. The experiment compares
%different BSS extration methods and various number of channels as input. It is
%important for evaluating the model order problem.
%
%
% --
% fecgsyn toolbox, version 1.2, Jan 2017
% Released under the GNU General Public License
%
% Copyright (C) 2014  Joachim Behar & Fernando Andreotti
% University of Oxford, Intelligent Patient Monitoring Group - Oxford 2014
% joachim.behar@oxfordalumni.org, fernando.andreotti@eng.ox.ac.uk
%
%
% For more information visit: https://www.physionet.org/physiotools/ipmcode/fecgsyn/
%
% Referencing this work
%
%   Behar Joachim, Andreotti Fernando, Zaunseder Sebastian, Li Qiao, Oster Julien, Clifford Gari D.
%   An ECG simulator for generating maternal-foetal activity mixtures on abdominal ECG recordings.
%   Physiological Measurement.35 1537-1550. 2014.
%
% Last updated : 10-03-2016
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

%% Input parameters
fs_new = 250;       % signals will be resample to 250 Hz

ch = {[11 22],[1 11 22 32],[1 8 11 22 25 32],[1 8 11 14 19 22 25 32], ...
    [1 3 6 8 11 14 19 22 25 27 30 32], ...
    [1 3 6 8 9 11 14 16 17 19 22 24 25  27 30 32],...
    1:32}; % trying with 4, 6, 8, 12, 16 and 32 channels

cd(path)


fls = dir('*.mat');     % looking for .mat (creating index)
fls =  arrayfun(@(x)x.name,fls,'UniformOutput',false);
% == core function
NB_REC = length(fls);
NB_RUN = length(ch);
stats_struct = cell(NB_RUN,1);
try
    cd([path slashchar 'exp1' slashchar])
catch
    mkdir([path slashchar 'exp1' slashchar])
    cd([path slashchar 'exp1' slashchar])
end

% Saving filter coefficients
HF_CUT = 100; % high cut frequency
LF_CUT = 3; % low cut frequency
[b_lp,a_lp] = butter(5,HF_CUT/(fs_new/2),'low');
[b_bas,a_bas] = butter(3,LF_CUT/(fs_new/2),'high');

for k = 1:NB_RUN
    for i = 1:NB_REC
        disp('>>>>>>>>>>>>>>>>>>>>>')
        fprintf('processing case with %f channels \n',length(ch{k}));
        %  diary(['log' num2str(length(ch{k})) '.txt'])
        %  diary on                                                              
        % = loading data
        load([path fls{i}])
        disp(num2str(i))
        if isempty(out.noise)
            noise = zeros(size(out.mecg));
        else
            noise = sum(cat(3,out.noise{:}),3);
        end
        fs = out.param.fs;
        INTERV = round(0.05*fs);     % BxB acceptance interval
        TH = 0.3;                    % detector threshold
        REFRAC = round(.15*fs)/1000; % detector refractory period
        mixture = double(out.mecg) + sum(cat(3,out.fecg{:}),3) ...
            + noise;                 % re-creating abdominal mixture
        mixture = mixture(ch{k},:)./3000;  % reducing number of channels, applying gain
        
        % = preprocessing channels
        ppmixture = zeros(size(mixture,1),size(mixture,2)/(fs/fs_new));
        for j=1:length(ch{k})
            ppmixture(j,:) = resample(mixture(j,:),fs_new,fs);    % reducing number of channels
            lpmix = filtfilt(b_lp,a_lp,ppmixture(j,:));
            ppmixture(j,:) = filtfilt(b_bas,a_bas,lpmix);
            fref = round(out.fqrs{1}./(fs/fs_new));
        end
        
        % = run extraction
        for met = {'FASTICA_DEF','FASTICA_SYM','JADEICA','PCA'}
            disp('==============================');
            disp(['Extracting file ' fls{i} '..']);
            disp(['Recording number ' num2str(i)])
            disp(['Number of channels simulation: ' num2str(length(ch{k}))])
            disp(['The ICA method used is ' met{:}]);                                                                                             
            
            % == extraction
            % = using ICA (FASTICA or JADE)
            
            disp('ICA extraction ..')
            loopsec = 60;   % in seconds
            %filename = [path slashchar 'exp1' slashchar met{:} '_nbch' num2str(length(ch{k})) '_rec' num2str(i)];
            icasig = FECGSYN_bss_extraction(ppmixture,met{:},fs_new,loopsec,1);     % extract using IC
            % Calculate quality measures
            qrs = FECGSYN_QRSmincompare(icasig,fref,fs_new);
            if isempty(qrs)
                F1= 0;
                RMS = NaN;
                PPV = 0;
                SE = 0;
            else
                [F1,RMS,PPV,SE] = Bxb_compare(fref,qrs,INTERV);
            end
            eval(['stats_' met{:} '(i,:) = [F1,RMS,PPV,SE];'])
        end
    end
    stats_struct{k}.stats_pca = stats_PCA;
    stats_struct{k}.stats_FASTICA_DEF = stats_FASTICA_DEF;
    stats_struct{k}.stats_FASTICA_SYM = stats_FASTICA_SYM;
    stats_struct{k}.stats_JADEICA = stats_JADEICA;
    %         diary off            
    save([path slashchar 'exp1' slashchar 'stats_ch_' num2str(k)],'stats_struct');
end


% == statistics
mean_FASTICA_SYM = zeros(NB_RUN,1);
median_FASTICA_SYM = zeros(NB_RUN,1);
mean_JADEICA = zeros(NB_RUN,1);
median_JADEICA = zeros(NB_RUN,1);
mean_FASTICA_DEF = zeros(NB_RUN,1);
median_FASTICA_DEF = zeros(NB_RUN,1);
mean_pca = zeros(NB_RUN,1);
median_pca = zeros(NB_RUN,1);
for kk=1:NB_RUN
    mean_FASTICA_DEF(kk) = mean(stats_struct{kk}.stats_FASTICA_DEF(1:NB_REC,1));
    median_FASTICA_DEF(kk) = median(stats_struct{kk}.stats_FASTICA_DEF(1:NB_REC,1));
    mean_FASTICA_SYM(kk) = mean(stats_struct{kk}.stats_FASTICA_SYM(1:NB_REC,1));
    median_FASTICA_SYM(kk) = median(stats_struct{kk}.stats_FASTICA_SYM(1:NB_REC,1));
    mean_JADEICA(kk) = mean(stats_struct{kk}.stats_JADEICA(1:NB_REC,1));
    median_JADEICA(kk) = median(stats_struct{kk}.stats_JADEICA(1:NB_REC,1));
    mean_pca(kk) = mean(stats_struct{kk}.stats_pca(1:NB_REC,1));
    median_pca(kk) = median(stats_struct{kk}.stats_pca(1:NB_REC,1));
end
end