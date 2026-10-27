function genda_A_worker(c)
genda_A_activate(c);
if c.options.useParallel, maxNumCompThreads(1); end
old=rng; cleanup=onCleanup(@() rng(old));
rng(987650,'twister');
cfg=original_A_adapter('config',c.base); cfg.number_of_steps=2;
result=original_A_adapter('execute',cfg,c.base);
assert(result.success,'Native warm-up failed: %s',result.error_message);
end
