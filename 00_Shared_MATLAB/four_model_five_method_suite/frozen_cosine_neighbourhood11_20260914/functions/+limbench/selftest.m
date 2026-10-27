function selftest(mode)
% SELFTEST Synthetic old/new regression, archived-query replay, and API tests.
% No ODE is needed by default. selftest('ode') also checks real integrations.
if nargin<1, mode='fast'; end
c=limbench.defaults(); c.maxSeconds=Inf; c.synthetic=true;
m=limbench.model('quadratic_cubic',.4);
for step=[.05 .025]
    c.scanStep=step;
    for seed=1:3
        rng(seed,'twister'); [old,~,a]=frozen_search_v1('angular_improved',m,c);
        rng(seed,'twister'); [new,~,b]=limbench.proposed(m,c);
        assert(isequaln(a{:,1:12},b{:,1:12}),'Candidate sequence changed.');
        assert(isequaln(old.R,new.R) && old.queries==new.queries);
        assert(strcmp(old.reason,new.reason) && old.directions==new.directions);
    end
end
fprintf('PASS: frozen-vs-packaged candidates, brackets, outputs and stops.\n');
fixtureRoot=fullfile(fileparts(mfilename('fullpath')),'private','fixtures');
replay(fullfile(fixtureRoot,'quadratic_cubic_04_step_005_seed01.csv'), ...
    limbench.model('quadratic_cubic',.4),.05);
replay(fullfile(fixtureRoot,'quadratic_cubic_04_step_0025_seed01.csv'), ...
    limbench.model('quadratic_cubic',.4),.025);
replay(fullfile(fixtureRoot,'bistable_duffing_07_step_005_seed01.csv'), ...
    limbench.model('bistable_duffing',.7),.05);
fprintf('PASS: archived physical-query traces replayed without an ODE.\n');

% Exact state transitions from the original bisection logic.
c=limbench.defaults(); m=limbench.model('quadratic_cubic',.4);
s=struct('count',0,'hasConv',false,'hasDiv',false,'conv',[0 0],'div',[NaN NaN]);
[x,s]=bisection_next(s,2,[1 0],[1 0;.8 0],2,1,m,c);
assert(norm(x-[.4 0])<eps && s.count==1 && s.hasDiv && ~s.hasConv);
[x,s]=bisection_next(s,1,[.4 0],[.4 0],1,.8,m,c);
assert(norm(x-[.6 0])<1e-14 && s.count==2 && s.hasConv);
[x,s]=bisection_next(s,2,[.6 0],[.6 0],1,.6,m,c);
assert(norm(x-[.5 0])<1e-14 && s.count==3);
[~,s]=bisection_next(s,0,[.5 0],[.5 0],1,.6,m,c);
assert(~s.hasConv && ~s.hasDiv && s.count==0);
fprintf('PASS: original bisection branches and explicit unknown reset.\n');

c.synthetic=true; c.queryBudget=20; c.maxSeconds=Inf;
methods={'coarse_GA','fine_GA','dynin_original_bisection','proposed_method','energy_informed'};
for j=1:numel(methods)
    rng(3,'twister'); [r,h,q]=limbench.run(methods{j},m,c);
    assert(r.queries<=20 && height(q)==r.queries);
    assert(r.rhs==0 && r.odeCalls==0 && r.unknown==0);
    assert(all(diff(h.runtime_s)>=0));
    assert(h.runtime_s(end)==r.runtime);
end
fprintf('PASS: five-method shared interface, query budget and accounting.\n');

% A timeout cannot produce a zero-time success; unknown cannot shrink radius.
c.queryBudget=4; c.maxSeconds=Inf;
[r,~,q]=baseline_engine('dynin_original_bisection',m,c,@unknown_oracle,tic);
assert(isnan(r.R) && r.unknown==4 && all(q.label==0));
[r,~,~]=angular_engine('angular_improved',m,c,@unknown_oracle,tic);
assert(isnan(r.R) && r.unknown==4);
ref=struct('R',1); c.maxSeconds=3; c.relativeThresholds=.01;
h=table([1;2],[1;1.2],[1;2],zeros(2,1),zeros(2,1),zeros(2,1),zeros(2,1), ...
    'VariableNames',{'traj_evals','LIM','runtime_s','rhs_evals','unknown_evals','n_directions','ode_trajectories'});
t=limbench.accuracy_times(h,ref,c);
assert(t.first_hit_s==1 && ~t.sustained_hit && isnan(t.sustained_time_s));
assert(t.capped_time_s==3);
h.LIM=[NaN;1]; h.runtime_s=[1;3.1];
t=limbench.accuracy_times(h,ref,c); assert(~t.sustained_hit);
fprintf('PASS: unknown handling and retrospective horizon censoring.\n');

[r,~]=limbench.reference('quadratic_cubic',.4);
assert(abs(r.R-.6474801597003332)<1e-9);
[r,~]=limbench.reference('bistable_duffing',.7);
assert(abs(r.R-.728927859156115)<1e-9);
fprintf('PASS: analytical reference evaluation (scoring only).\n');

if strcmp(mode,'ode')
    c=limbench.defaults(); c.maxSeconds=Inf; c.queryBudget=100;
    m=limbench.model('quadratic_cubic',.4);
    assert(limbench.classify([0 0],m,c)==1);
    assert(limbench.classify([1.1 .2],m,c)==2);
    [label,n,t,traj]=limbench.classify([.4 .6],m,c); %#ok<ASGLU>
    assert(ismember(label,[1 2]) && n>0 && t>0 && size(traj,2)==2);
    rng(5,'twister'); [old,~,a]=frozen_search_v1('angular_improved',m,c);
    rng(5,'twister'); [new,~,b]=limbench.proposed(m,c);
    assert(isequaln(a{:,1:12},b{:,1:12}) && isequaln(old.R,new.R));
    m=limbench.model('bistable_duffing',.7);
    assert(limbench.classify([-1 0],m,c)==1);
    assert(limbench.classify([1 0],m,c)==2);
    fprintf('PASS: real ODE classifier and frozen-sequence regression.\n');
end
fprintf('All requested limbench tests passed.\n');
end

function replay(file,m,step)
assert(isfile(file),'Missing archived-query regression fixture.');
gold=readtable(file); count=0;
c=limbench.defaults(); c.scanStep=step; c.maxSeconds=Inf;
rng(1,'twister');
[r,~,q]=angular_engine('angular_improved',m,c,@oracle,tic);
assert(count==height(gold) && height(q)==height(gold));
assert(all(abs(q.radius-gold.radius)<2e-12));
assert(isequal(q.label,gold.label));
assert(abs(r.R-min(gold.radius(gold.label==2)))<2e-12);
assert(strcmp(r.reason,'heuristic_plateau_with_coverage'));
    function [label,n,t]=oracle(x)
        count=count+1; assert(count<=height(gold),'Too many replay queries.');
        assert(norm(x-[gold.x0(count) gold.v0(count)])<2e-12,'Archived point sequence changed.');
        label=gold.label(count); n=gold.rhs_evals(count); t=gold.integration_end_time(count);
    end
end

function [label,n,t,traj]=unknown_oracle(x)
label=0; n=0; t=0; traj=x;
end
