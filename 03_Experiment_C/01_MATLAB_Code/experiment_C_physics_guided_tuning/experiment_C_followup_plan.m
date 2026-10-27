% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function varargout=experiment_C_followup_plan(action,varargin)
% Prespecified profiles and budget admission, independent of LIM reference.
switch char(action)
    case 'profiles'
        initial=varargin{1}; f=varargin{2}; cfg=varargin{3};
        ids=["period_only";"double_period";"decay_estimate"; ...
            "grid_first";"time_first"];
        P=repmat(initial,5,1);
        for i=1:5
            P(i).rule_id=ids(i);
            P(i).tfinal=min(f.timeFromPeriod,cfg.maximumTime);
        end
        P(2).tfinal=min(2*f.timeFromPeriod,cfg.maximumTime);
        P(3).tfinal=initial.tfinal;
        varargout={P};
    case 'constants'
        cfg=varargin{1};
        % Seeds and budgets may change for a frozen independent confirmation.
        varargout={rmfield(cfg,{'mode','seeds','budgets'})};
    case 'eligible'
        p=varargin{1}; audit=varargin{2};
        varargout={logical(p.calibration_pass && p.verification_pass && ...
            audit.diagnostic_pass && p.geometry_ok)};
    case 'schedule'
        P=varargin{1}; cfg=varargin{2}; model=char(varargin{3}); alpha=varargin{4};
        rows=cell(0,1);
        for i=1:height(P)
            for budget=reshape(cfg.budgets,1,[])
                for seed=reshape(cfg.seeds,1,[])
                    actual=mod(seed*1000003+round(alpha*10000)+sum(double(model))*37,2^32-1);
                    rows{end+1,1}=struct('rule_id',P.rule_id(i), ...
                        'number_of_steps',budget,'seed',seed,'algorithm_seed',actual, ...
                        'run_key',P.rule_id(i)+"_N"+string(budget)+"_seed_"+string(seed)); %#ok<AGROW>
                end
            end
        end
        S=struct2table(vertcat(rows{:}));
        stream=RandStream('mt19937ar','Seed',20260923+round(alpha*10000)+sum(double(model)));
        S=S(randperm(stream,height(S)),:);
        S.execution_order=(1:height(S))';
        varargout={S};
    otherwise
        error('Unknown follow-up plan action.');
end
end
