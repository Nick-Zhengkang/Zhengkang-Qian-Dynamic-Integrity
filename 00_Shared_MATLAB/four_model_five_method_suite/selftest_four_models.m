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
function selftest_four_models()
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'functions'));
limbench.verify_freeze();
for name={'quadratic_cubic','bistable_duffing'}
    if strcmp(name{1},'quadratic_cubic'), values=.1:.1:.9; else, values=.1:.1:1; end
    for a=values
        [r,~]=fourbench.reference(name{1},a); assert(isfinite(r.R) && r.R>0);
        m1=fourbench.model(name{1},a); m2=limbench.model(name{1},a);
        assert(isequal(m1.target,m2.target) && isequal(m1.weight,m2.weight));
    end
end
% The old and new entry points must make identical decisions on synthetic data.
m=limbench.model('quadratic_cubic',.4); c=limbench.defaults();
c.synthetic=true; c.maxSeconds=Inf;
rng(11); [r1,~,q1]=limbench.proposed(m,c);
rng(11); [r2,~,q2]=limbench.proposed_four_models(m,c);
assert(r1.R==r2.R && isequaln(q1(:,1:12),q2(:,1:12)));
c.synthetic=false;
for name={'paper_unforced_duffing','genda_cosine_quadratic_drag'}
    m=fourbench.model(name{1},.05); [r,~]=fourbench.reference(name{1},.05);
    assert(isfinite(r.R) && r.R>0);
    [label,~,~]=fourbench.classify_extension(m.target,m,c); assert(label==1);
    if strcmp(name{1},'paper_unforced_duffing'), x=[1 0]; else, x=[pi+.01 0]; end
    [label,~,~]=fourbench.classify_extension(x,m,c); assert(label==2);
    rng(1); [res,~,q]=limbench.proposed_four_models(m,c);
    assert(isfinite(res.R) && res.R>0 && ~isempty(q));
    assert(max(abs(q.radius-q.weighted_radius_check))<1e-10);
end
fprintf('PASS: references, frozen routing, new classifiers and weighted geometry.\n');
end
