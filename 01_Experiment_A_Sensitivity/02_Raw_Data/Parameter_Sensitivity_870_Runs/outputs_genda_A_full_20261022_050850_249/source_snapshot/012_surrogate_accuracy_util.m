function varargout=surrogate_accuracy_util(action,varargin)
% Shared scoring, persistence, and reporting; none changes the search inputs.
switch action
    case 'constraints'
        varargout={ [0 0 0 .2 -1 0;0 0 0 -.6 1 0; ...
            0 0 0 -1 1 0;0 0 0 -1 0 1], [0;0;-4;0] };
    case 'score'
        R=varargin{1};
        assert(~isempty(R) && all([R.valid_for_score]), ...
            'surrogate_accuracy:InvalidBatch', ...
            'At least one run failed. No failed seed is dropped from the objective.');
        varargout{1}=median([R.absolute_error]);
    case 'save'
        file=varargin{1}; data=varargin{2}; temp=[file '.tmp.mat'];
        save(temp,'-struct','data','-v7');
        [ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
    case 'table'
        T=varargin{1}; file=varargin{2}; temp=[file '.tmp.csv'];
        writetable(T,temp);
        [ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
    case 'export'
        folder=varargin{1};
        R=read_records(fullfile(folder,'records'),'rows');
        S=read_records(fullfile(folder,'observations'),'summary');
        if ~isempty(R)
            surrogate_accuracy_util('table',R,fullfile(folder,'raw_data_all_runs.csv'));
        end
        if ~isempty(S)
            S=sortrows(S,{'median_absolute_error','config_id','restart'});
            surrogate_accuracy_util('table',S,fullfile(folder,'search_configurations.csv'));
        end
        varargout={R,S};
    case 'confirmation'
        B=varargin{1}; Q=varargin{2}; o=varargin{3};
        assert(isequal([B.seed],[Q.seed]),'Confirmation pairs are misaligned.');
        eb=surrogate_accuracy_util('score',B); eq=surrogate_accuracy_util('score',Q);
        tb=median([B.core_wall_time_s]); tq=median([Q.core_wall_time_s]);
        stream=RandStream('mt19937ar','Seed',o.bootstrapSeed);
        delta=zeros(o.bootstrapSamples,1); delta10=delta;
        be=[B.absolute_error]; qe=[Q.absolute_error]; n=numel(be);
        for j=1:o.bootstrapSamples
            ix=randi(stream,n,n,1);
            mb=median(be(ix)); mq=median(qe(ix));
            delta(j)=mq-mb; delta10(j)=mq-mb/10;
        end
        gain=NaN;
        if eq>0, gain=eb/eq; elseif eb>0, gain=Inf; end
        C=table(n,eb,eq,prctile(be,95),prctile(qe,95),tb,tq,tq/tb,gain, ...
            eq-eb,prctile(delta,95),prctile(delta10,95),eq<eb, ...
            eb>0 && eq<=eb/10,prctile(delta,95)<0, ...
            'VariableNames',{'paired_seeds','baseline_median_absolute_error', ...
            'candidate_median_absolute_error','baseline_p95_absolute_error', ...
            'candidate_p95_absolute_error','baseline_median_core_time_s', ...
            'candidate_median_core_time_s','descriptive_time_ratio', ...
            'error_reduction_factor','median_error_difference', ...
            'error_difference_upper95','tenfold_difference_upper95', ...
            'observed_error_improvement','observed_tenfold_improvement', ...
            'bootstrap_supports_error_improvement'});
        C.pilot_only=~strcmp(o.mode,'full');
        C.synthetic=o.synthetic;
        varargout{1}=C;
    otherwise
        error('Unknown utility action: %s',action);
end
end

function T=read_records(folder,field)
files=dir(fullfile(folder,'*.mat'));
files=files(~endsWith(string({files.name}),'.tmp.mat'));
cells=cell(numel(files),1);
for j=1:numel(files)
    a=load(fullfile(files(j).folder,files(j).name),field);
    cells{j}=a.(field);
end
T=table();
if ~isempty(cells), T=struct2table(vertcat(cells{:})); end
end
