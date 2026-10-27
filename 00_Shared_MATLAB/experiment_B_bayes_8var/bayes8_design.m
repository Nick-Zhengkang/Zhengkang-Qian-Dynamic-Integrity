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
function out=bayes8_design(action,varargin)
% Extend the existing six-coordinate design without changing old experiments.
names={'qk','discr','generations','population','newcomers','selected', ...
    'number_of_steps','Ts'};
switch action
    case 'names'
        out=names;
    case 'table'
        X=varargin{1}; assert(size(X,2)==8);
        out=array2table(X,'VariableNames',names);
    case 'matrix'
        out=varargin{1}{:,names};
    case 'baseline'
        b=varargin{1};
        out=[bayes_A_design('baseline',b) b.number_of_steps b.Ts];
    case 'feasible'
        X=varargin{1}; o=varargin{2};
        if istable(X), X=X{:,names}; end
        assert(size(X,2)==8);
        six=o; six.lower=o.lower(1:6); six.upper=o.upper(1:6);
        out=bayes_A_design('feasible',X(:,1:6),six) ...
            & all(isfinite(X),2) & all(X>=o.lower & X<=o.upper,2) ...
            & X(:,7)==round(X(:,7));
    case 'key'
        x=varargin{1}; assert(isequal(size(x),[1 8]));
        % Exact IEEE representation avoids collisions between nearby real Ts.
        out=sprintf('%s_b%d_t%s',bayes_A_design('key',x(1:6)),x(7),num2hex(x(8)));
    case 'config'
        x=varargin{1}; b=varargin{2}; assert(isequal(size(x),[1 8]));
        out=bayes_A_design('config',x(1:6),b);
        out.number_of_steps=x(7); out.Ts=x(8);
        out.config_id=string(bayes8_design('key',x));
    otherwise
        error('Unknown eight-variable design action: %s',action);
end
end
