function t = predictionTable(picks,data)
t=struct2table(picks);
t.event_id=string({data.event_id})';t.source_id=string({data.source_id})';
t.p_true_sec=[data.p_arrival_sec]';t.s_true_sec=[data.s_arrival_sec]';
t.p_error_ms=1000*(t.p_pred_sec-t.p_true_sec);t.s_error_ms=1000*(t.s_pred_sec-t.s_true_sec);
end
