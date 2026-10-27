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
function [C,baselineId,meta]=top6_design(o,base)
% Exhaust ALL Cartesian combinations, not random parameter combinations.
if nargin<2, base=original_A_adapter('base'); end
c=original_A_adapter('config',base);
c.requested_newcomer_ratio=c.newcomer_fraction;
c=identify(c); baselineId=c.config_id;
total=numel(o.kValues)*numel(o.gridValues)*numel(o.generationValues)* ...
    numel(o.newcomerRatioValues)*numel(o.populationValues)*numel(o.selectedValues);
C=repmat(c,1,total); i=0;
for k=o.kValues
    for n=o.gridValues
        for g=o.generationValues
            for f=o.newcomerRatioValues
                for p=o.populationValues
                    for s=o.selectedValues
                        q=c;
                        q.num_of_cell_around_equilibrium=k; q.discr=n;
                        q.num_gen=g; q.population_size=p; q.selected_opt=s;
                        q.requested_newcomer_ratio=f;
                        q.newcomers=round(p*f);
                        q.newcomer_fraction=q.newcomers/p;
                        % One retained best individual; clones stay at baseline.
                        q.num_crossover=p-1-q.newcomers-q.num_almost_clones;
                        assert(q.num_crossover>=1 && s>=2 && s<=p && q.newcomers>=1, ...
                            'Invalid composition. This exhaustive design must not silently omit combinations.');
                        i=i+1; C(i)=identify(q);
                    end
                end
            end
        end
    end
end
ids=string({C.config_id});
assert(numel(unique(ids))==total,'Duplicate effective configurations after rounding.');
assert(nnz(ids==baselineId)==1,'The grid must contain the baseline exactly once.');
meta.full_configurations=total;
if strcmp(o.mode,'smoke')
    C=C([find(ids==baselineId,1) 1]);
end
meta.executed_configurations=numel(C);
meta.planned_runs=numel(C)*numel(o.seeds);
end

function c=identify(c)
c.config_id=string(sprintf('n%d_k%d_g%d_p%d_new%d_cl%d_sel%d_N%d_d%d_f%d_T%.6g', ...
    c.discr,c.num_of_cell_around_equilibrium,c.num_gen,c.population_size, ...
    c.newcomers,c.num_almost_clones,c.selected_opt,c.number_of_steps,c.divR, ...
    c.rep_fix_point,c.Ts));
end
