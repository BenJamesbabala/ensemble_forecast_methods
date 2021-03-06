LM_ensemble_ts_para = function(target, target_test, nmodel, Kmax, test_number, rank){
  error = ones(nmodel, 1) * Inf
  variable_number = ncol(target_all1) -1
  error = ones(nmodel, 1) * Inf
  b = ones(1, test_number)/test_number
  
  temp_final = matrix (data = NA, nmodel, test_number)
  sale_final = matrix (data = NA, nmodel, test_number)
  lowsale_final = matrix (data = NA, nmodel, test_number)
  upsale_final = matrix (data = NA, nmodel, test_number)
  index_final = vector(mode = "list", length = nmodel)
  number_factor = vector(mode = "list", length = nmodel)
  stime <- system.time({
    for (K in 1:Kmax)
    {
      print (K)
      test = combn (variable_number,K)+ 1
      temp =matrix (data = NA, test_number, ncol(test))
      temp1 =matrix (data = NA, test_number, ncol(test))
      sale =matrix (data = NA, test_number, ncol(test))
      lower_sale =matrix (data = NA, test_number, ncol(test))
      upper_sale =matrix (data = NA, test_number, ncol(test))
      
      K_results <- foreach (i = 1:ncol(test), .combine = cbind)  %dopar%
      {
        index_predictor = c(1,test[, i])
        modelData = target[1:(nrow(target)-test_number), index_predictor, drop = FALSE]
        fit_std =lm(response ~ . , data = modelData)
        newdata =data.frame(target[nrow(target):(nrow(target)-test_number + 1), test[, i], drop = FALSE])
        pred_sale = predict(fit_std, newdata, interval = "prediction")
        temp[, i]= (pred_sale[,1]/ target[nrow(target):(nrow(target)-test_number + 1), 1]-1) * 100
        sale[,i] = pred_sale[, 1]
        lower_sale[, i]=pred_sale[, 2]
        upper_sale[, i]=pred_sale[, 3]
        
        list(i, sum(as.matrix( b * abs(temp[1:test_number, i]))) , temp[, i], sale[, i], lower_sale[, i], upper_sale[, i], K)
      }
      K_results= as.matrix(K_results)
      
      if (min(unlist(K_results[2,]), na.rm = TRUE)< max(error))
      {
        total_error = rbind(as.matrix(unlist(K_results[2,])), error)
        index_model = order(total_error, na.last = TRUE, decreasing = FALSE)[1:nmodel]
        
        temp_final = rbind(matrix(unlist(K_results[3,]), ncol = test_number, byrow = TRUE), temp_final)[index_model, ]
        sale_final = rbind(matrix(unlist(K_results[4,]), ncol = test_number, byrow = TRUE), sale_final)[index_model, ]
        lowsale_final = rbind(matrix(unlist(K_results[5,]), ncol = test_number, byrow = TRUE), lowsale_final)[index_model, ]
        upsale_final = rbind(matrix(unlist(K_results[6,]), ncol = test_number, byrow = TRUE), upsale_final)[index_model, ]
        index_final = append(split(test, col(test)), index_final)[index_model]
        
        error = as.matrix(total_error[index_model])
      }
    }
  })
  
  test = total_error[index_model]
  quartz()
  barplot(test[1:nmodel])
  
  if (nmodel>=4){
    ansmean=cpt.meanvar(test[1:nmodel])
    par(mar=c(5,6,4,2))
    plot(ansmean,yaxt="n", xaxt="n",cpt.col='dark blue', cpt.width=5, lwd = 5, xlab ='', ylab ='')
    axis(2, cex.axis=2)
    axis(1, cex.axis=2)
    title(xlab = 'order of models', cex.lab=2)
    title(ylab = 'MAPE on validation set', cex.lab=2)
    
    print(ansmean)
    model_max = ansmean@cpts[1]
  }else{
    model_max = nmodel
  }
  
  
  
  ##########################
  if (rank){
  rep = 20
  error_permuate = array(data=NA, dim=c(model_max,rep, ncol(target) -1))
  for (ii in 1:(ncol(target)-1))
  {
    for(iii in 1:rep)
    {
      
      target_p = target
      target_p[, ii+1] = target[sample(1:nrow(target), nrow(target), replace = FALSE), ii+1]
      for (i in 1:model_max)
      {
        index_predictor = c(1, index_final[[i]])
        modelData = target_p[1:(nrow(target)-test_number), index_predictor, drop = FALSE]
        newdata =target_p[(nrow(target)-test_number + 1):nrow(target), index_final[[i]] , drop = FALSE]
        fit_std =lm(response ~ . , data = modelData)
        pred_sale = predict(fit_std, newdata, interval = "prediction")[,1]
        error_permuate[i, iii, ii] = mean(abs((pred_sale/ target[(nrow(target)-test_number + 1):nrow(target), 1]-1) * 100))
      }
    }
  }
  
  
  output = rbind(names(target)[order(apply(error_permuate, 3, mean, trim = .2), decreasing=T) + 1],
                 sort(apply(error_permuate, 3, mean, trim = .2), decreasing = T))
  quartz()
  par(las=2) # make label text perpendicular to axis
  par(mar=c(5,15,4,2)) # increase y-axis margin.
  barplot(as.numeric(rev(output[2,1:5])), horiz=TRUE, xlab='MAPE increase',names.arg=rev(output[1,1:5]), 
          cex.names =2, cex.lab = 2, cex.axis= 1.2, col=rainbow(10))
  } else{
    output = 'Did not rank'
    }

  ########################################
  # forecast 
  #########################################
  pred_sale = array(data=NA, dim=c(nrow(target_test), 3, model_max))
  
  
  for (i in 1:model_max)
  {
    names(target_all1)[index_final[[i]]]
    index_predictor = c(1, index_final[[i]])
    modelData = target
    modelData = modelData[, index_predictor, drop = FALSE]
    fit_std =lm(response ~  ., data = modelData)
    new = target_test[, index_predictor[2:length(index_predictor)], drop = FALSE]
    pred_sale[, , i] = predict(fit_std, new, interval = "prediction")
  }

  return (list(frct_value = mean(pred_sale[, 1, ]), models_lm_output_perrow = pred_sale, variables_rank = output))
}
